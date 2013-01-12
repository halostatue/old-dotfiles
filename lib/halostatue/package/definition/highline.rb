# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/definition'

class Halostatue::Package::Definition::Highline < Halostatue::Package
  default_package

  include Halostatue::Package::Type::Git

  url "git://github.com/JEG2/highline.git"
  private_package
end
