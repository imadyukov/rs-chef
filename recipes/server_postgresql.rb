include_recipe "postgresql::server"
include_recipe "postgresql::config_initdb"
include_recipe "postgresql::config_pgtune"

# Create the databases
pg_user = "postgres"

class Chef::Resource
  include Opscode::PostgresqlHelpers
end

###
# Create the opscode_chef database, migrate it, and create the users we need, and grant them
# privileges.
###
db_name = "opscode_chef"

execute "create #{db_name} database" do
  command "/usr/bin/createdb -T template0 --port 5432 -E UTF-8 #{db_name}"
  user pg_user
  not_if { execute_sql('\l').split("\n").select{|x| x.match(/^#{db_name}\|/)}.size > 0 }
  retries 30
  notifies :run, 'execute[install_schema]', :immediately
end

execute "install_schema" do
  command "/opt/chef-server/embedded/bin/sqitch --db-user #{pg_user} deploy --verify" # same as preflight
  cwd "/opt/chef-server/embedded/service/chef-server-schema"
  user pg_user
  action :nothing
end

# Create Database Users
node['postgresql']['password'].each do |pg_u, pg_p|
  next if pg_u == pg_user

  ruby_block "Create #{pg_u} user in postgresql" do
    block do
      execute_sql("CREATE USER #{pg_u} PASSWORD '#{pg_p}';")
    end
    not_if { execute_sql('\du').split("\n").select{|x| x.match(/^#{pg_u}\|/)}.size > 0 }
  end

  grant_commands = if pg_u.end_with?("_ro")
    [
      "GRANT CONNECT ON DATABASE #{db_name} TO #{pg_u};",
      "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO #{pg_u};",
      "GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO #{pg_u};",
      "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO #{pg_u};",
      "GRANT SELECT ON ALL TABLES IN SCHEMA public TO #{pg_u}",
    ]
  else
    [
      "GRANT CONNECT, TEMPORARY ON DATABASE #{db_name} TO #{pg_u};",
      "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, UPDATE ON SEQUENCES TO #{pg_u};",
      "GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO #{pg_u};",
      "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT INSERT, SELECT, UPDATE, DELETE ON TABLES TO #{pg_u};",
      "GRANT INSERT, SELECT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO #{pg_u}",
    ]
  end + [
    "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO #{pg_u};",
    "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO #{pg_u};",
  ]

  grant_commands.each do |grant_command|
    ruby_block grant_command do
      block do
        execute_sql(grant_command)
      end
    end
  end

end
