#
# Install AWS SDK for Ruby
#

%w(gcc libxml2-devel libxslt-devel).each do |pkg|
  package pkg do
    action :nothing
  end.run_action(:install)
end

gem_package "aws-sdk" do
  gem_binary ::File.join(::File.dirname(Gem.ruby), "gem")
  action :nothing
  options("-- --use-system-libraries")
end.run_action(:install)
Gem.clear_paths

#######################################################################

#
# Check / Create the s3 bucket to be used for cookbook files of chef server.
#
require 'aws-sdk'

bucket_name = "#{node[:coupa][:deployment].chars.select{|x| x.match(/[a-z0-9]/)}.join}chef.#{node[:coupa][:serverdomain]}"

api = AWS::S3.new(:access_key_id => node[:coupa][:s3][:access_key], :secret_access_key => node[:coupa][:s3][:secret_key])
unless api.buckets[bucket_name].exists?
  api.buckets.create(bucket_name)
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
  command "yum install -y https://opscode-omnibus-packages.s3.amazonaws.com/el/6/x86_64/chef-server-#{node[:chef][:server][:version]}.el6.x86_64.rpm"
  not_if { system("yum info chef-server") }
end

#######################################################################
#
# External database for chef server
#

include_recipe "rs-chef::server_postgresql"

#######################################################################

#
# Configure chef server
#

directory "/etc/chef-server"

file "/etc/chef-server/chef-validator.pem" do
  mode 0600
  content node[:chef][:client][:validator_pem]
end

chef_server_options = {
  'postgresql' => {
    'enable' => false,
    'sql_password' => node['postgresql']['password']['opscode_chef'],
    'sql_ro_password' => node['postgresql']['password']['opscode_chef_ro'],
    'vip' => node[:chef][:server][:db_endpoint].split(":").first,
  },
  'bookshelf' => {
    'enable' => false,
    'url' => "https://s3.amazonaws.com",
    'external_url' => "https://s3.amazonaws.com",
    'access_key_id' => node[:coupa][:s3][:access_key],
    'secret_access_key' => node[:coupa][:s3][:secret_key],
  },
  'erchef' => {
    's3_bucket' => bucket_name,
  }
}

file "/etc/chef-server/chef-server.rb" do
  mode 0400
  content(chef_server_options.map do |obj, obj_hash|
      obj_hash.map do |obj_atr, atr_val|
        atr_val = atr_val.kind_of?(String) ? "'#{atr_val}'" : atr_val
        "#{obj}['#{obj_atr}'] = #{atr_val}"
      end
    end.flatten.join("\n") + "\n")
end

execute "chef-server-ctl reconfigure"

#######################################################################
