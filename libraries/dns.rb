class Chef
  class Resource
    class CoupaDns < Chef::Resource

      def initialize(name, run_context=nil)
        super
        @resource_name = :coupa_dns
        @provider = Chef::Provider::CoupaDns
        @action = :update
        @allowed_actions = [:nothing, :update]

        @dns_name = name
        @dns_domain = nil
        @dns_ip = nil
        @api_key = nil
        @secret_key = nil
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

      def api_key(arg=nil)
        set_or_return(:api_key, arg, :kind_of => String)
      end

      def secret_key(arg=nil)
        set_or_return(:secret_key, arg, :kind_of => String)
      end

    end
  end
end

class Chef
  class Provider
    class CoupaDns < Chef::Provider

      def load_current_resource
        unless @current_resource
          require 'dnsmadeeasy/api'

          @api = DnsMadeEasy::Api.new(new_resource.api_key, new_resource.secret_key)
        end

        @current_resource || Chef::Resource::CoupaDns.new(new_resource.name)
      end

      def action_update
        Chef::Log.error("The name #{@new_resource.dns_name} doesn't satisfy RFC 952 and RFC 1123. Skip.") and return unless @new_resource.dns_name.match(/^(?![0-9]+$)(?!-)[a-z0-9\-.]{,63}(?<!-)$/)

        Chef::Log.error("dns_domain and dns_ip are required!") and return if (@new_resource.dns_domain.nil? || @new_resource.dns_ip.nil?)

        if (r = @api.list_records(@new_resource.dns_domain, :name => @new_resource.dns_name)).empty?
          @api.create_record!(@new_resource.dns_domain, :name => @new_resource.dns_name, :type => 'A', :data => @new_resource.dns_ip, :ttl => 60)
        else
          record_id = r.first[:id]
          record_value = r.first[:data]
          return if record_value == @new_resource.dns_ip

          @api.update_record!(@new_resource.dns_domain, record_id, :data => @new_resource.dns_ip)
        end

        @new_resource.updated_by_last_action true
      end

    end
  end
end
