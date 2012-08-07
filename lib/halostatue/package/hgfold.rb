# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::HGFold < Halostatue::Package
  name 'hgfold'

  def update_hgrc
    touch installer.source_file.join('hgrc')
    Rake::Task[:install].invoke
  end
  private :update_hgrc

  def install(task)
    fail_if_installed
    sh %Q(hg clone bb+ssh://bradobro/hgfold #{target})
    update_hgrc
  end

  def uninstall(task)
    fail_unless_installed
    target.rmtree
    update_hgrc
  end

  def update(task)
    fail_unless_installed
    Dir.chdir(target) do
      sh %Q(hg pull && hg update)
      update_hgrc
    end
  end
end
