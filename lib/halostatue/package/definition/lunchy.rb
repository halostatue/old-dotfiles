# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/definition'

class Halostatue::Package::Definition::Lunchy < Halostatue::Package
  include Halostatue::Package::Type::Git

  url "git://github.com/mperham/lunchy.git"
  has_plugin

  def plugin_init_file
    %Q(add-paths-before-if "#{target.join('bin')}")
  end
end
