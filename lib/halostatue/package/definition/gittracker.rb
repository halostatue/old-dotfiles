# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/definition'

class Halostatue::Package::Definition::GitTracker < Halostatue::Package
  include Halostatue::Package::Type::Git

  url "git://github.com/highgroove/git_tracker.git"
end
