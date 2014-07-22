node.override['postgresql']['enable_pgdg_yum'] = true
node.override['postgresql']['version'] = '9.3'

node.override['postgresql']['client']['packages'] = ["postgresql#{node['postgresql']['version'].split('.').join}-devel"]
node.override['postgresql']['server']['packages'] = ["postgresql#{node['postgresql']['version'].split('.').join}-server"]
node.override['postgresql']['contrib']['packages'] = ["postgresql#{node['postgresql']['version'].split('.').join}-contrib"]
node.override['postgresql']['dir'] = "/var/lib/pgsql/#{node['postgresql']['version']}/data"
node.override['postgresql']['server']['service_name'] = "postgresql-#{node['postgresql']['version']}"

node.override['postgresql']['config_pgtune']['db_type'] = 'oltp'
node.override['postgresql']['config_pgtune']['listen_addresses'] = '0.0.0.0'

node.override['postgresql']['password']['postgres']        = 'md5d4dd6397cf55a4507874c3864f092a8c'
node.override['postgresql']['password']['opscode_chef'] = 'raf7ahW2'
node.override['postgresql']['password']['opscode_chef_ro'] = 'Bi5sheeb'
