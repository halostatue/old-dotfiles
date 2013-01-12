# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/definition'

class Halostatue::Package::Definition::GMVault < Halostatue::Package
  include Halostatue::Package::Type::VirtualEnv

  has_plugin

  def plugin_functions
    {
      :gmvault => zsh_autoload(gmvault_function)
    }
  end

  def gmvault_function
    %Q<(cd #{target.join('bin')} && ./gmvault "${@}")>
  end
end
