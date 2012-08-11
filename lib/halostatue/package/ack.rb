# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'open-uri'

class Halostatue::Package::Ack < Halostatue::Package
  def install(task)
    target.mkpath

    temp = target.join('ack-new')
    file = target.join('ack')

    temp.delete if temp.exist?
    open("http://betterthangrep.com/ack-standalone") { |r|
      File.open(temp.to_path, 'w') { |w| w.write r.read }
    }

    type = %x(file "#{temp.to_path}")

    if type =~ /a perl script text executable/
      file.delete if file.exist?
      temp.rename(temp.dirname.join(file.basename))
      file.chmod(0755)
    else
      warn "ack could not be installed (type: #{type})"
    end
  end

  def uninstall(task)
    fail_unless_installed
    target.rmtree
  end

  def update(task)
    install(task)
  end
end
