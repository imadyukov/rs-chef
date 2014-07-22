name             "rs-chef"
maintainer       "RightScale, Inc."
maintainer_email "support@rightscale.com"
license          "Copyright RightScale, Inc. All rights reserved."
description      "Installs and configures the Chef Client and Server"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "15.0.0"

supports "centos"
supports "redhat"
supports "ubuntu"

recipe "rs-chef::client",
  "Installs and configures the Chef Client."

recipe "rs-chef::do_client_converge",
  "Allows manual update/re-run of runlist on the Chef Client."

recipe "rs-chef::do_unregister_request",
  "Deletes the node and registered client on the Chef Server."

recipe "rs-chef::client",
  "Propagate coupa attributes"

recipe "rs-chef::server",
  "Installs and configures chef server"

attribute "chef/client/version",
  :display_name => "Chef Client Version",
  :description =>
    "Specify the Chef Client version to match requirements of your Chef" +
    " Server. Example: 11.12.8-2",
  :required => "optional",
  :default => "11.12.8-2",
  :recipes => ["rs-chef::client"]

attribute "chef/client/server_url",
  :display_name => "Chef Server URL",
  :description =>
    "Enter the URL to connect to the remote Chef Server. To connect to the" +
    " Opscode Hosted Chef use the following syntax" +
    " https://api.opscode.com/organizations/ORGNAME." +
    " Example: http://example.com:4000/chef",
  :required => "required",
  :recipes => ["rs-chef::client"]

attribute "chef/client/validator_pem",
  :display_name => "Private Key to Register the Chef Client with the Chef" +
    " Server",
  :description =>
    "Private SSH key which will be used to authenticate the Chef Client on" +
    " the remote Chef Server.",
  :required => "required",
  :recipes => ["rs-chef::client"]

attribute "chef/client/validation_name",
  :display_name => "Chef Client Validation Name",
  :description =>
    "Validation name, along with the private SSH key, is used to determine" +
    " whether the Chef Client may register with the Chef Server. The" +
    " validation_name located on the Server and in the Client configuration" +
    " file must match. Example: ORG-validator",
  :required => "required",
  :recipes => ["rs-chef::client"]

attribute "chef/client/node_name",
  :display_name => "Chef Client Node Name",
  :description =>
    "Name which will be used to authenticate the Chef Client on the remote" +
    " Chef Server. If nothing is specified, the instance FQDN will be used." +
    " Example: chef-client-host1",
  :required => "optional",
  :recipes => ["rs-chef::client"]

attribute "chef/client/environment",
  :display_name => "Chef Client Environment",
  :description =>
    "Specify the environment type for the Chef Client configuration file." +
    " Example: development",
  :required => "optional",
  :default => "_default",
  :recipes => ["rs-chef::client"]

attribute "chef/client/company",
  :display_name => "Chef Company Name",
  :description =>
    "Company name to be set in the Client configuration file. This attribute" +
    " is applicable for Opscode Hosted Chef Server. The company name" +
    " specified in both the Server and the Client configuration file must" +
    " match. Example: MyCompany",
  :required => "optional",
  :recipes => ["rs-chef::client"]

attribute "chef/client/roles",
  :display_name => "Set of Client Roles",
  :description =>
    "Comma-separated list of roles which will be applied to this instance." +
    " The Chef Client will execute the roles in the order specified here." +
    " Example: webserver, monitoring",
  :required => "optional",
  :recipes => ["rs-chef::client", "rs-chef::do_client_converge"]

attribute "chef/client/runlist_override",
  :display_name => "JSON String used to override the first run of chef-client.",
  :description =>
    "A custom JSON string to override the first run of chef-client." +
    " Example: recipe[ntp::default]",
  :required => "optional",
  :recipes => ["rs-chef::client"]

attribute "chef/client/log_level",
  :display_name => "Logging Level",
  :description =>
    "The level of logging that will be stored in the log file. Example: debug",
  :required => "optional",
  :default => "info",
  :recipes => ["rs-chef::client"]

attribute "chef/client/log_location",
  :display_name => "Log File Location",
  :description =>
    "The location of the log file. Example: /var/log/chef-client.log",
  :required => "optional",
  :default => "/var/log/chef-client.log",
  :recipes => ["rs-chef::client"]

attribute "chef/client/data_bag_secret",
  :display_name => "Data Bag Secret Key",
  :description =>
    "A secret key used to encrypt data bag items." +
    " Example: cred:CHEF_DATA_BAG_SECRET",
  :required => "optional",
  :default => "",
  :recipes => ["rs-chef::client"]

attribute "coupa/deployment",
  :display_name => "Coupa Deployment",
  :description =>
    "Specify the deployment name",
  :required => "required",
  :recipes => ["rs-chef::client", "rs-chef::server"]

attribute "coupa/serverdomain",
  :display_name => "Coupa serverdomain",
  :description =>
    "Specify the serverdomain coupadev.com/coupahost.com",
  :required => "required",
  :choice => ["coupadev.com", "coupahost.com"],
  :recipes => ["rs-chef::client", "rs-chef::server"]

attribute "coupa/nodename",
  :display_name => "Node name for the server",
  :description =>
    "Specify the nickname",
  :required => "optional",
  :default => "",
  :recipes => ["rs-chef::client"]

# Enable EBS is needed
attribute "coupa/vol/stripe_count",
  :display_name => "How many stripes of EBS",
  :description =>
    "Number of stripes for volume, dafault is 0 meaning do not attach any volume",
  :required => "optional",
  :recipes => ["rs-chef::client"]

attribute "coupa/vol/iops",
  :display_name => "Total IOPS",
  :description =>
    "IOPS for all the volume stripes, default is none",
  :required => "optional",
  :recipes => ["rs-chef::client"]

attribute "coupa/vol/size",
  :display_name => "Total size for all stripes",
  :description =>
    "Total size in GB, sum of all volume stripes, default is 50GB",
  :required => "optional",
  :recipes => ["rs-chef::client"]

# Change DNSMadeEasy Id
attribute "coupa/dns/update",
  :display_name => "Change the DNS record",
  :description =>
    "Setting none do not change anything, private_ip to change dns to server local_ip or pick public IP for EIP",
  :required => "optional",
  :choice => ["none", "private_ip", "public_ip"],
  :recipes => ["rs-chef::client"]

attribute "coupa/dns/id",
  :display_name => "Id of the record",
  :description =>
    "Id of the DNS record at the DNS provider",
  :required => "optional",
  :recipes => ["rs-chef::client"]

attribute "coupa/dns/provider",
  :display_name => "DNS provider",
  :description =>
    "Enable persistent volume, on AWS that is additional EBS volume, default DNSMadeEasy",
  :required => "optional",
  :choice => ["DNSMadeEasy"],
  :recipes => ["rs-chef::client"]

attribute "coupa/s3/access_key",
  :display_name => "AWS ACCESS KEY for S3",
  :description =>
    "The aws access key to be used to work with S3 buckets",
  :required => true,
  :recipes => ["rs-chef::server"]

attribute "coupa/s3/secret_key",
  :display_name => "AWS SECRET KEY for S3",
  :description =>
    "The aws access secret key to be used to work with S3 buckets",
  :required => true,
  :recipes => ["rs-chef::server"]
