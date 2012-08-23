# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::PivotalLS < Halostatue::Package
  include Halostatue::Package::GitPackage

  url "git://github.com/shyndman/pivotal-ls.git"
end
