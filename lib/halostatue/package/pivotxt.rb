# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::Pivotxt < Halostatue::Package
  include Halostatue::Package::GitPackage

  url "git://github.com/gabehollombe/Pivotxt.git"
end
