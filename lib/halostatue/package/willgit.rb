# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::WillGit < Halostatue::Package
  include Halostatue::Package::GitPackage

  default_package
  url "git://gitorious.org/willgit/mainline.git"
end
