# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::GitPivotal < Halostatue::Package
  include Halostatue::Package::GitPackage

  url "git://github.com/trydionel/git-pivotal.git"
end
