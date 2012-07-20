# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::HGFold < Halostatue::Package
  name 'hgfold'

  def install(task)
    target_path = installer.source_file.join("packages")
    target_path.mkpath
    target = target_path.join('hgfold')

    sh %Q(hg clone bb+ssh://bradobro/hgfold #{target})
    touch installer.source_file.join("hgrc")
    Rake::Task[:install].invoke
  end

  def uninstall(task)
    target = installer.source_file.join("packages/hgfold")
    if target.directory?
      target.rmtree
      touch installer.source_file.join("hgrc")
      Rake::Task[:install].invoke
    end
  end

  description :update, "Update package {{package.name}}"
  def update(task)
    target = installer.source_file.join("packages/hgfold")
    if target.directory?
      Dir.chdir(target) do
        sh %Q(hg pull && hg update)
        touch installer.source_file.join("hgrc")
        Rake::Task[:install].invoke
      end
    end
  end
end
