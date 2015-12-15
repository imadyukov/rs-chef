require 'yaml'
require 'base64'
require 'zlib'
require 'json'

gem_package "ohai" do
  gem_binary("/opt/ruby/bin/gem")
  version("7.4.1")
  action :install
end

gem_package "chef" do
  gem_binary("/opt/ruby/bin/gem")
  version("11.18.12")#node[:chef][:client][:gem_version])
  action :install
end

if node['chef']['server']['is_master'] == "true"
 is_backup_machine = true
end

package "postgresql-devel" do
  only_if { is_backup_machine }
end

directory "/etc/coupa/chef_server" do
  recursive true
  mode 0700
end

server_settings_file = File.read('/etc/opscode/chef-server-running.json')
server_settings_hash = JSON.parse(server_settings_file)

file "/etc/coupa/chef_server/pg.yaml" do
  content({
    'user' => "opscode-pgsql",
    'password' => server_settings_hash['private_chef']['postgresql']['db_superuser_password'],
    'host' => "127.0.0.1",
    }.to_yaml)
  action (is_backup_machine ? :create : :delete)
end

file "/etc/coupa/chef_server/chef_replication.pem" do
  content node['chef']['server']['replication_key']
  mode 0600
  action (is_backup_machine ? :create : :delete)
end

execute "extract chef-replication pub key" do
  command "openssl rsa -in /etc/coupa/chef_server/chef_replication.pem -pubout > /etc/coupa/chef_server/chef_replication.pub"
  action :run
  notifies :run, 'execute[add replication user]', :immediately
  creates "/etc/coupa/chef_server/chef_replication.pub"
end

execute "add replication user" do
  command "chef-server-ctl user-create chef_replication Coupa Replication #{node[:chef][:server][:replication_email]} #{node[:chef][:server][:replication_passwd]} -f /tmp/chef_replication.key"
  action :nothing
  notifies :run, 'execute[add replication user to org]', :immediately
  notifies :run, 'execute[add replication key]', :immediately
end

execute "add replication user to org" do
  command "chef-server-ctl org-user-add coupa chef_replication --admin"
  action :nothing
end

execute "add replication key" do
  command "chef-server-ctl add-user-key chef_replication --public-key-path /etc/coupa/chef_server/chef_replication.pub --key-name replication"
  action :nothing
end

replicate_to = eval(node['chef']['server']['replicate_to']) || {}

replicate_to.each do |chef_url, chef_items|
  template "/etc/coupa/chef_server/knife-replicate-to-#{Zlib.crc32(chef_url)}.rb" do
    source "knife-replicate-to.rb"
    variables({
      :chef_server_url => chef_url
      })
    action (is_backup_machine ? :create : :delete)
  end
end

chef_node_name = node[:chef][:server][:node_name].chars.select {|x| x.match(/[a-z0-9A-Z_-]/)}.join

template "/etc/coupa/chef_server/knife.rb" do
  source "knife-replicate-to.rb"
  variables({
    #https://devchf315srv1.coupadev.com/organizations/coupa
    :chef_server_url => "https://#{chef_node_name}.#{node['coupa']['serverdomain']}/organizations/coupa"
    #:chef_server_url => Chef::Config.chef_server_url
    })
  action (is_backup_machine ? :create : :delete)
end

file "/etc/coupa/chef_server/git_writeable_key" do
  content node['coupa']['git_writeable_key']
  mode 0600
  action (is_backup_machine ? :create : :delete)
end

file "/etc/coupa/chef_server/git_key" do
  content node['coupa']['git_key']
  mode 0600
  action (is_backup_machine ? :create : :delete)
end

file "/etc/coupa/chef_server/git_writeable_key.wrapper" do
  content "ssh -o StrictHostKeychecking=no -i /etc/coupa/chef_server/git_writeable_key $@"
  mode 0700
  action (is_backup_machine ? :create : :delete)
end

file "/etc/coupa/chef_server/git_key.wrapper" do
  content "ssh -o StrictHostKeychecking=no -i /etc/coupa/chef_server/git_key $@"
  mode 0700
  action (is_backup_machine ? :create : :delete)
end

execute "Create fake git repo" do
  command "git init --bare /opt/coupa/var/chef-backup/fake-repo"
  not_if "test -d /opt/coupa/var/chef-backup/fake-repo/info"
end

git_repo = "file:///opt/coupa/var/chef-backup/fake-repo"

directory "/opt/coupa/var/chef-backup/cache" do
  recursive true
  mode 0700
end

git "/opt/coupa/var/coupa-base" do
  repository "git@github.com:coupa-ops/coupa-base.git"
  ssh_wrapper "/etc/coupa/chef_server/git_key.wrapper"
  only_if {
    is_backup_machine
  }
end

link "/opt/coupa/lib" do
  to "/opt/coupa/var/coupa-base/libraries"
end

file "/opt/coupa/lib/init.rb" do
  content lazy { IO.read('/opt/coupa/var/coupa-base/libraries/helper.rb') }
  mode 0755
  action (is_backup_machine ? :create : :delete)
end

git "/opt/coupa/var/chef-backup/scripts" do
  repository "git@github.com:coupa-ops/chef-core.git"
  ssh_wrapper "/etc/coupa/chef_server/git_writeable_key.wrapper"
  only_if {
    is_backup_machine
  }
end

file "/opt/coupa/var/chef-backup/scripts/scripts/backup/backup.yaml" do
  content({
    "git_user_name" => chef_node_name,
    "git_user_email" => "ops12@coupa.com",
    "git_repo" => git_repo,
    "cache_dir" => "/opt/coupa/var/chef-backup/cache",
    "envs" => {
      "main" => {
        "git_branch" => "master",
        "knife_config_file" => "/etc/coupa/chef_server/knife.rb",
        "chef_objects" => ["environment", "role", "data_bag", "cookbook"],
        "commit" => ["environment", "role", "data_bag"],
        "replicate" => replicate_to.map do |chef_url, chef_items|
          {
            "knife_config" => "/etc/coupa/chef_server/knife-replicate-to-#{Zlib.crc32(chef_url)}.rb",
            "chef_objects" => chef_items,
          }
        end
      }
    }
  }.to_yaml)
  action (is_backup_machine ? :create : :delete)
end

cron "Backup chef stuff" do
  command "PATH=/opt/ruby/bin:$PATH ; flock -n /opt/coupa/var/chef-backup/scripts/scripts/backup/backup.yaml /opt/coupa/var/chef-backup/scripts/scripts/backup/backup.rb --commit #{"--ssh-wrapper /etc/coupa/chef_server/git_writeable_key.wrapper" unless git_repo.start_with?("file://")} >>/var/log/chef-backup.log 2>&1 ; echo $? >/var/run/chef-backup.status"
  minute "*/10"
  path "/opt/ruby/bin:/bin:/usr/bin"
  action (is_backup_machine ? :create : :delete)
end

=begin
cookbook_file "/etc/logrotate.d/chef-backup" do
  source "etc/logrotate.d/chef-backup"
  action (is_backup_machine ? :create : :delete)
end
=end

=begin
include_recipe "coupa-base::monitoring"

if is_backup_machine
  r = resources(:template => "/etc/collectd.d/exec.conf")
  r.variables({
    :name => r.variables[:name],
    :options => r.variables[:options].merge({
      "Exec nobody \"/usr/lib64/collectd/status-file.rb\"" => "/var/run/chef-backup.status",
      })
    })
end

coupa_alert "Chef Server Backup/Replication" do
  condition "process-status/gauge-chef_backup.value>=1"
  duration 25
  condition_action :escalate
  condition_action_attribute alert_escalate_to
  action (is_backup_machine ? :create : :delete)
  only_if { rightscale? }
end
=end
