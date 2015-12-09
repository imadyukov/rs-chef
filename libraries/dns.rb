class Chef
  class Resource
    class CoupaDns < Chef::Resource

      def initialize(name, run_context=nil)
        super
        @resource_name = :coupa_dns
        @provider = Chef::Provider::CoupaDns
        @action = :update
        @allowed_actions = [:nothing, :update, :cname]

        @dns_name = name
        @dns_domain = nil
        @dns_ip = nil
      end

      def dns_name(arg=nil)
        arg.downcase! unless arg.nil?
        set_or_return(:dns_name, arg, :kind_of => String)
      end

      def dns_domain(arg=nil)
        set_or_return(:dns_domain, arg, :kind_of => String)
      end

      def dns_ip(arg=nil)
        set_or_return(:dns_ip, arg, :kind_of => String)
      end

    end
  end
end

class Chef
  class Provider
    class CoupaDns < Chef::Provider

      require 'socket'
      #require_relative "helper"
      #include Coupa::Base::Helper

      def load_current_resource
        @current_resource || Chef::Resource::CoupaDns.new(new_resource.name)
      end

      def api
        @@dns_made_easy_api ||= begin
          require 'dnsmadeeasy/api'
          #RestClient.log = nil

          api_key = node['coupa']['dns']['api_key']
          secret_key = node['coupa']['dns']['api_secret']
          DnsMadeEasy::Api.new(api_key, secret_key)
        end
      end

      def action_update

        Chef::Log.error("dns_domain and dns_ip are required!") and return if (@new_resource.dns_domain.nil? || @new_resource.dns_ip.nil?)

        begin
          addr = IPSocket.getaddress(@new_resource.dns_name + "." + @new_resource.dns_domain)
          return if addr == @new_resource.dns_ip
        rescue SocketError
        end

        if (r = api.list_records(@new_resource.dns_domain, :name => @new_resource.dns_name)).empty?
          api.create_record!(@new_resource.dns_domain, :name => @new_resource.dns_name, :type => 'A', :data => @new_resource.dns_ip, :ttl => 60)
        else
          record_id = r.first[:id]

          api.update_record!(@new_resource.dns_domain, record_id, :data => @new_resource.dns_ip)
        end

        @new_resource.updated_by_last_action true
      end

      def action_cname
        begin
          return if Socket.gethostbyname(
            "#{new_resource.dns_name}.#{new_resource.dns_domain}").first == \
                    "#{new_resource.dns_ip}.#{new_resource.dns_domain}"
        rescue SocketError
        end

        exist_record = api.list_records(
          new_resource.dns_domain,
          name: new_resource.dns_name,
          type: 'CNAME')

        if exist_record.empty?
          Chef::Log.info "Creating record #{new_resource.dns_name} -> " \
          "CNAME -> #{new_resource.dns_ip} within " \
          "domain #{new_resource.dns_domain}"
          reties = 0
          begin
            api.create_record!(
              new_resource.dns_domain,
              name: new_resource.dns_name,
              type: 'CNAME',
              data: new_resource.dns_ip,
              ttl: 60)
          rescue DnsMadeEasy::BadRequestError => e
            reties += 1
            raise if reties > 1
            Chef::Log.warn "Got exception: #{e.inspect}"
            if e.message.include?('already exists with this name.')
              Chef::Log.info 'Remove a records with this name'
              api.list_records(
                new_resource.dns_domain,
                name: new_resource.dns_name
              ).each do |x|
                Chef::Log.info "Remove record #{x[:id]} points to #{x[:data]}"
                api.delete_record!(new_resource.dns_domain, x[:id])
              end
              Chef::Log.info 'Retry create a record with the given options'
              retry
            end
            raise
          end
        else
          Chef::Log.info "Updating record #{new_resource.dns_name} -> " \
          "CNAME -> #{new_resource.dns_ip} within " \
          "domain #{new_resource.dns_domain}"
          api.update_record!(
            new_resource.dns_domain,
            exist_record.first[:id],
            data: new_resource.dns_ip,
            type: 'CNAME')
        end

        new_resource.updated_by_last_action true
      end # def action_cname
    end # class CoupaDns
  end
end

