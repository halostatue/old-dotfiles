# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::Pybugz < Halostatue::Package
  include Halostatue::Package::GitPackage

  url "git://github.com/williamh/pybugz.git"
end
