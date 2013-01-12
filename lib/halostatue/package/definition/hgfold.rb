# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/definition'

class Halostatue::Package::Definition::HgFold < Halostatue::Package
  default_package

  include Halostatue::Package::Type::Hg

  url "bb://bradobro/hgfold"

  def after_action(task)
    update_config_file 'hgrc'
  end
  private :after_action

  alias_method :post_install, :after_action
  alias_method :post_uninstall, :after_action
  alias_method :post_update, :after_action
end
