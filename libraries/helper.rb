module Rschef 
  module Helper

  def launchtime
    if File.exists?("/etc/launchtime")
      File.read("/etc/launchtime")
    else
      launchtime = "#{Time.now.strftime("%Y%m%d-%H%M%S")}"
      File.open('/etc/launchtime', 'w') { |file| file.write(launchtime) }
      launchtime 
    end
  end

  end
end


