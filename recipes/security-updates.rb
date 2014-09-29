execute "bash upgrade" do
  command "rpm -Uvh https://s3.amazonaws.com/packages.#{node['coupa']['serverdomain']}/bash-4.1.2-15.el6_5.2.x86_64.rpm"
  only_if "env x='() { :;}; echo -n vulnerable ' bash -c 'echo' | grep vulnerable"
end
