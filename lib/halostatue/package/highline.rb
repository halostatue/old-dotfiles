# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::Highline < Halostatue::Package
  include Halostatue::Package::GitPackage

  url "git://github.com/JEG2/highline.git"
  private_package
end
