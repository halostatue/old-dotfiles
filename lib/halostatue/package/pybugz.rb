# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::Pybugz < Halostatue::Package
  name 'pybugz'

  def install(task)
    target_path = installer.source_file.join("packages")
    target_path.mkpath
    target = target_path.join('pybugz')

    sh %Q(git clone git://github.com/williamh/pybugz.git #{target})
  end

  def uninstall(task)
    target = installer.source_file.join("packages/pybugz")
    target.rmtree if target.directory?
  end

  description :update, "Update package {{package.name}}"
  def update(task)
    target = installer.source_file.join("packages/pybugz")
    if target.directory?
      Dir.chdir(target) do
        sh %Q(git pull)
      end
    end
  end
end
