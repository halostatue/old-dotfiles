# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/definition'

class Halostatue::Package::Definition::WillGit < Halostatue::Package
  include Halostatue::Package::Type::Git

  default_package
  url "git://gitorious.org/willgit/mainline.git"
  has_plugin

  def plugin_init_file
    <<-EOS
add-paths-before-if "#{target.parent.join('bin')}"
    EOS
  end
end
