# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/definition'

class Halostatue::Package::Definition::Chruby < Halostatue::Package
  include Halostatue::Package::Type::Git

  url "https://github.com/postmodern/chruby.git"
  path ':name/src'
  has_plugin

  def remove_paths(task)
    target.parent.expand_path.rmtree
  end
  private :remove_paths

  alias_method :post_uninstall, :remove_paths

  def install_with_makefile(task)
    Dir.chdir(target) do
      sh %Q(make install PREFIX=#{target.parent.expand_path})
    end
  end
  private :install_with_makefile

  alias_method :post_install, :install_with_makefile
  alias_method :post_update, :install_with_makefile

  def plugin_init_file
    <<-EOS
add-paths-before-if "#{target.parent.join('bin')}"
unique-manpath -b "#{target.parent.join('share/man')}"

source "#{target.parent.join('share/chruby/chruby.sh')}"
source "#{target.parent.join('share/chruby/auth.sh')}"
    EOS
  end
end
