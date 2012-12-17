# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::HgFold < Halostatue::Package
  default_package

  include Halostatue::Package::HgPackage

  url "bb://bradobro/hgfold"

  def after_action(task)
    update_hgrc
  end
  private :after_action

  alias_method :post_install, :after_action
  alias_method :post_uninstall, :after_action
  alias_method :post_update, :after_action
end
