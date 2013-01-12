# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/definition'

class Halostatue::Package::Definition::HTTPie < Halostatue::Package
  include Halostatue::Package::Type::VirtualEnv

  has_plugin

  def plugin_functions
    {
      :http => zsh_autoload(httpie_function)
    }
  end

  def httpie_function
    %Q<(cd #{target.join('bin')} && ./http "${@}")>
  end
end
