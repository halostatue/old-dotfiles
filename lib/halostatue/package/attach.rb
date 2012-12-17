# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::Spot < Halostatue::Package
  include Halostatue::Package::GitPackage

  url "git://github.com/sorin-ionescu/attach.git"
  path ':name/src'

  def make_paths(task)
    %W(bin share/man/man1).each do |stem|
      target.parent.join(stem).expand_path.mkpath
    end
  end
  private :make_paths

  alias_method :pre_install, :make_paths
  alias_method :pre_update, :make_paths

  def remove_paths(task)
    target.parent.expand_path.rmtree
  end
  private :remove_paths

  alias_method :post_uninstall, :remove_paths

  def install_with_symlinks(task)
    parent  = target.parent
    bin     = parent.join('bin/attach')

    installer.fileops.ln_s target.join('attach'), bin unless bin.exist?
    installer.fileops.ln_s target.join('attach.1'), man unless man.exist?
  end
  private :install_with_symlinks

  alias_method :post_install, :install_with_symlinks
  alias_method :post_update, :install_with_symlinks
end
