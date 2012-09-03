# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::HgFold < Halostatue::Package
  default_package

  include Halostatue::Package::HgPackage

  url "bb://bradobro/hgfold"

  def update_hgrc(task)
    touch installer.source_file.join('hgrc')
    Rake::Task[:install].invoke
  end
  private :update_hgrc

  alias_method :post_install, :update_hgrc
  alias_method :post_uninstall, :update_hgrc
  alias_method :post_update, :update_hgrc
end
