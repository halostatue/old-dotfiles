# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/definition'

class Halostatue::Package::Definition::PivotalLS < Halostatue::Package
  include Halostatue::Package::Type::Git

  url "git://github.com/shyndman/pivotal-ls.git"
end
