# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/definition'

class Halostatue::Package::Definition::HTTPie < Halostatue::Package
  include Halostatue::Package::Type::VirtualEnv

  def pip_name
    "https://github.com/jkbr/httpie/tarball/master"
  end

  has_plugin

  def plugin_functions
    {
      :http => zsh_autoload(http_function),
      :httpie => zsh_autoload(httpie_function),
    }
  end

  def http_function
    %Q<(cd #{target.join('bin')} && ./http "${@}")>
  end

  def httpie_function
    %Q<(cd #{target.join('bin')} && ./httpie "${@}")>
  end
end
