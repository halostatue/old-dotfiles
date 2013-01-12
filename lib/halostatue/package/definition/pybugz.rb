# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/definition'

class Halostatue::Package::Definition::Pybugz < Halostatue::Package
  include Halostatue::Package::Type::Git

  url "git://github.com/williamh/pybugz.git"

  def plugin_functions
    {
      :bugz => zsh_autoload(pybugz_function)
    }
  end

  def pybugz_function
    %Q<#{target.join('lbugz')} "${@}">
  end
end
