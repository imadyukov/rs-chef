execute "bash upgrade" do
  command "rpm -Uvh https://s3.amazonaws.com/packages.#{node['coupa']['serverdomain']}/bash-4.1.2-15.el6_5.2.x86_64.rpm"
  only_if "env x='() { :;}; echo -n vulnerable ' bash -c 'echo' | grep vulnerable"
end

bash "openssl update" do
  code <<-EOH
    cp -p /etc/yum.repos.d/CentOS-updates.repo /etc/yum.repos.d/CentOS-updates.repo.orig
    repodate=$(date -d '1 day ago' +"%Y%m%d")
    sed --in-place "s%/archive/20[0-9]*%/archive/$repodate%" /etc/yum.repos.d/CentOS-updates.repo
    yum clean all
    yum -y update openssl
    yum -y update openssl-devel
    yum -y --security update
    mv /etc/yum.repos.d/CentOS-updates.repo.orig /etc/yum.repos.d/CentOS-updates.repo
    yum clean all
  EOH
end
