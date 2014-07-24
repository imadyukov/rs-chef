node.override['collectd']['fqdn'] = node['rightscale']['instance_uuid']

include_recipe "collectd::default"

collectd_plugin "syslog"
collectd_plugin "interface" do
  options(:Interface => "eth0")
end
collectd_plugin "cpu"
collectd_plugin "df" do
  options({
    :report_reserved => false,
    "FSType" => ["proc", "sysfs", "fusectl", "debugfs", "securityfs", "devtmpfs", "devpts", "tmpfs"],
    :ignore_selected => true,
  })
end
collectd_plugin "disk"
collectd_plugin "memory"
collectd_plugin "processes"
collectd_plugin "load"
collectd_plugin "users"

collectd_plugin 'network' do
  options({
    "Server \"#{node[:coupa][:rs_sketchy]}\"" => "3011",
  })
end

collectd_plugin "swap"
collectd_plugin "conntrack"
collectd_plugin "contextswitch"


include_recipe "machine_tag::default"

machine_tag "rs_monitoring:state=active"
