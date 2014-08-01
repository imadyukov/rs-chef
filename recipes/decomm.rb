require 'json'

role = if ::File.exists?("/etc/chef/runlist.json")
  JSON.parse(::File.open("/etc/chef/runlist.json").read)['run_list'].map do |ri|
    (ri.match(/^role\[([a-z_-]+).*\]$/) || [])[1]
  end.compact.first
else
  nil
end

execute "Run decommission role: #{role}_decomm" do
  command "chef-client -o role[#{role}_decomm] -L /dev/stdout -l info 2>&1"
  only_if { !role.nil? && system("/opt/coupa/bin/does_role_exist.rb #{role}_decomm") }
end
