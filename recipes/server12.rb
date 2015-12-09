# Override some attributes
#
if Gem::Version.new(node[:chef][:server][:version]).release >= Gem::Version.new(12)
  node.normal[:chef][:server][:config_dir] = '/etc/opscode'
  node.normal[:chef][:server][:prefix] = '/opt/opscode'
end

#
# Install AWS SDK and DnsMadeEasy gems for Ruby
#

%w(gcc libxml2-devel libxslt-devel).each do |pkg|
  package pkg do
    action :nothing
  end.run_action(:install)
end

#######################################################################

#
# Monitoring
#

include_recipe "rs-chef::server_monitoring"

#######################################################################

#
# Install chef server
#

execute "Install chef server" do
  command begin
    chef_server_version = Gem::Version.new(node[:chef][:server][:version]).release
    url = if chef_server_version >= Gem::Version.new(12)
      "https://web-dl.packagecloud.io/chef/stable/packages/el/6/chef-server-core-#{chef_server_version}-1.el6.x86_64.rpm"
    else
      "https://web-dl.packagecloud.io/chef/stable/packages/el/6/chef-server-#{chef_server_version}-1.el6.x86_64.rpm"
    end
    "yum install -y #{url}"
  end
  not_if {
    system('yum info chef-server') || \
    system('yum info chef-server-core')
  }
end

directory "/etc/coupa/patches" do
  recursive true
end

remote_directory "/etc/coupa/patches" do
  source "etc/coupa/patches/chef#{Gem::Version.new(node[:chef][:server][:version]).segments.first}"
end

file "/etc/coupa/patches/apply.sh" do
  content lazy {
    "#!/bin/bash\n" + \
    ::Dir.glob("/etc/coupa/patches/*.patch").map do |patch|
      file = File.open(patch).read.scan(/\+\+\+\ (.*?)\ /).flatten.first
      "patch #{file} -i #{patch}"
    end.join("\n") + "\n"
  }
  mode 0700
end

execute "Apply Coupa patches for chef server" do
  command "/etc/coupa/patches/apply.sh && touch /etc/coupa/patches/apply.sh.done"
  creates '/etc/coupa/patches/apply.sh.done'
end

cookbook_file "/etc/logrotate.d/chef-server" do
  source "etc/logrotate.d/chef-server"
end

#######################################################################
#
# External database for chef server
#

#include_recipe "rs-chef::server_postgresql"

#######################################################################

#
# Configure chef server
#

directory node[:chef][:server][:config_dir]

file "#{node[:chef][:server][:config_dir]}/chef-validator.pem" do
  mode 0600
  content node[:chef][:client][:validator_pem]
end

file "#{node[:chef][:server][:config_dir]}/chef-webui.pem" do
  mode 0640
  content lazy {
    begin r = IO.popen("openssl genrsa 2048") ;r.read ensure r.close end
  }
  action :create_if_missing
end

directory "/etc/ssl/certs" do
  recursive true
end

directory "/etc/ssl/priv" do
  recursive true
  mode 0750
end

file "/etc/ssl/certs/chef.#{node[:coupa][:serverdomain]}" do
  content "#{node[:chef][:server][:ssl_cert]}\n#{node[:chef][:server][:ssl_ca_cert]}"
  not_if { node[:chef][:server][:ssl_cert].nil? }
end

file "/etc/ssl/priv/chef.#{node[:coupa][:serverdomain]}" do
  content node[:chef][:server][:ssl_cert_key]
  not_if { node[:chef][:server][:ssl_cert_key].nil? }
end

erchef_config_key = if Gem::Version.new(node[:chef][:server][:version]).release >= Gem::Version.new(12)
  'opscode_erchef'
else
  'erchef'
end

chef_server_options = {
  'nginx' => {
    'server_name' => "chef.#{node[:coupa][:serverdomain]}",
    'ssl_company_name' => "Coupa",
    'ssl_email_address' => "ops12@#{node[:coupa][:serverdomain]}",
    'ssl_locality_name' => "San Francisco",
    'ssl_state_name' => "CA",
    'url' => "https://127.0.0.1",
    'ssl_certificate' => node[:chef][:server][:ssl_cert].nil? ? nil : "/etc/ssl/certs/chef.#{node[:coupa][:serverdomain]}",
    'ssl_certificate_key' => node[:chef][:server][:ssl_cert_key].nil? ? nil : "/etc/ssl/priv/chef.#{node[:coupa][:serverdomain]}",
    'ssl_protocols' => "TLSv1 TLSv1.1 TLSv1.2",
    'ssl_ciphers' => "EECDH+ECDSA+AESGCM:EECDH+aRSA+AESGCM:EECDH+ECDSA+SHA256:EECDH+aRSA+SHA256:EECDH+ECDSA+SHA384:EECDH+ECDSA+SHA256:EECDH+aRSA+SHA384:EDH+aRSA+AESGCM:EDH+aRSA+SHA256:EDH+aRSA:EECDH:!aNULL:!eNULL:!MEDIUM:!LOW:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS:!RC4:!SEED:!SSLv2",
  }
}

file "#{node[:chef][:server][:config_dir]}/chef-server.rb" do
  mode 0400
  content(chef_server_options.map do |obj, obj_hash|
      obj_hash.map do |obj_atr, atr_val|
        case atr_val
        when String
          "#{obj}['#{obj_atr}'] = '#{atr_val}'"
        when NilClass
          "#{obj}['#{obj_atr}'] = nil"
        else
          "#{obj}['#{obj_atr}'] = #{atr_val}"
        end
      end
    end.flatten.join("\n") + "\n")
  notifies :run, 'execute[chef-server-ctl reconfigure]', :immediately
end

execute "chef-server-ctl reconfigure" do
  action :nothing
end

#######################################################################

execute "user-create" do
  command "chef-server-ctl user-create coupa_admin Coupa Admin #{node[:chef][:server][:admin_email]} #{node[:chef][:server][:admin_passwd]} -f #{node[:chef][:server][:config_dir]}/coupa_admin.pem"
  action :run
  creates "#{node[:chef][:server][:config_dir]}/coupa_admin.pem"
end

execute "org-create" do
  command "chef-server-ctl org-create coupa 'Coupa' --association_user coupa_admin --filename #{node[:chef][:server][:config_dir]}/coupa-validator.pem"
  action :run
  creates "#{node[:chef][:server][:config_dir]}/coupa-validator.pem"
end

execute "extract chef-validator pub key" do
  command "openssl rsa -in #{node[:chef][:server][:config_dir]}/chef-validator.pem -pubout > #{node[:chef][:server][:config_dir]}/chef-validator.pub"
  action :run
  notifies :run, 'execute[add validator key]', :immediately
  creates "#{node[:chef][:server][:config_dir]}/chef-validator.pub"
end

execute "add validator key" do
  command "chef-server-ctl add-client-key coupa coupa-validator --public-key-path /tmp/key.pub --key-name validation"
  action :nothing
end
