# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::Pybugz < Halostatue::Package
  def install(task)
    fail_if_installed
    sh %Q(git clone git://github.com/williamh/pybugz.git #{target})
  end

  def uninstall(task)
    fail_unless_installed
    target.rmtree
  end

  def update(task)
    fail_unless_installed
    Dir.chdir(target) { sh %Q(git pull) }
  end
end
