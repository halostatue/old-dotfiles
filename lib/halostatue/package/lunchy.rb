# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::Lunchy < Halostatue::Package
  include Halostatue::Package::GitPackage

  url "git://github.com/mperham/lunchy.git"
end
