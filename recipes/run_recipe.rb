json_file_name = "/etc/chef/run_recipe/#{Time.now.to_i}.json"

directory ::File.dirname(json_file_name) do
  mode 0700
end

file json_file_name do
  content node[:coupa][:run_recipe_json]
  not_if { node[:coupa][:run_recipe_json].nil? || node[:coupa][:run_recipe_json].empty? }
end

execute "Run custom recipe #{node[:coupa][:run_recipe]}" do
  command lazy {
    opt = ::File.exists?(json_file_name) ? "-j #{json_file_name}" : nil
    "chef-client -o #{node[:coupa][:run_recipe]} #{opt}"
  }
  environment({'HOME' => '/root'})
end
