# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::GitTracker < Halostatue::Package
  include Halostatue::Package::GitPackage

  url "git://github.com/highgroove/git_tracker.git"
end
