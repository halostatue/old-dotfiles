# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::ZshCompletions < Halostatue::Package
  include Halostatue::Package::GitPackage

  default_package
  url "git://github.com/zsh-users/zsh-completions.git"
end
