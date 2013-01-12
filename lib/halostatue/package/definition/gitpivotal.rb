# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/definition'

class Halostatue::Package::Definition::GitPivotal < Halostatue::Package
  include Halostatue::Package::Type::Git

  url "git://github.com/trydionel/git-pivotal.git"
end
