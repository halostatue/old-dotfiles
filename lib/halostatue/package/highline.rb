# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::Highline < Halostatue::Package
  name 'highline'
  private_package

  def install(task)
    if installed?
      Dir.chdir(target) { sh %Q(git pull) }
    else
      sh %Q(git clone git://github.com/JEG2/highline.git #{target})
    end
  end

  def uninstall(task)
    fail_unless_installed
    target.rmtree
  end
end
