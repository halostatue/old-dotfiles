# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::Spot < Halostatue::Package
  include Halostatue::Package::GitPackage

  url "git://github.com/guille/spot.git"
  path 'spot/src'

  def make_paths
    %W(bin share/man/man1).each do |stem|
      target.parent.join(stem).expand_path.mkpath
    end
  end
  private :make_paths

  alias_method :pre_install, :make_paths
  alias_method :pre_update, :make_paths

  def remove_paths
    target.parent.expand_path.rmtree
  end
  private :remove_paths

  alias_method :post_uninstall, :remove_paths

  def install_with_makefile
    Dir.chdir(target) do
      sh %Q(make install PREFIX=#{target.parent.expand_path})
    end
  end
  private :install_with_makefile

  alias_method :post_install, :install_with_makefile
  alias_method :post_update, :install_with_makefile
end
