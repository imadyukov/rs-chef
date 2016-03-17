node.override['postgresql']['enable_pgdg_yum'] = true
node.override['postgresql']['version'] = '9.3'

node.override['postgresql']['client']['packages'] = ["postgresql#{node['postgresql']['version'].split('.').join}-devel"]
node.override['postgresql']['contrib']['packages'] = ["postgresql#{node['postgresql']['version'].split('.').join}-contrib"]

default['postgresql']['password']['opscode_chef']    = ''
default['postgresql']['password']['opscode_chef_ro'] = ''
