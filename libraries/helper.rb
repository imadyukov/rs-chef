module Rschef
  module Helper
    def launchtime(opts = {})
      opts = {
        type: 'time',
        content: Time.now.strftime('%Y%m%d-%H%M%S')
      }.merge(opts)

      control_file = "/etc/launch#{opts[:type]}"
      if File.exist?(control_file)
        File.read(control_file)
      else
        File.open(control_file, 'w') { |file| file.write(opts[:content]) }
        opts[:content]
      end
    end

    def launchnodename(name)
      launchtime(type: 'nodename', content: name)
    end
  end
end
