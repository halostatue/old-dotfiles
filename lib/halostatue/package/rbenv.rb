# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::RbEnv < Halostatue::Package
  path Pathname.new('~/.rbenv').expand_path

  def install_or_update_repo(name, repo_path, url)
    puts "#{name}…"

    if repo_path.directory?
      if repo_path.join(".git").directory?
        sh %Q(command git pull)
        return
      else
        warn "Protecting non-git directory as #{repo_path.basename}.bak"
        repo_path.rename("#{repo_path}.bak")
      end
    elsif repo_path.file?
      warn "Protecting non-git file as #{repo_path.basename}.bak"
      repo_path.rename("#{repo_path}.bak")
    end

    sh %Q(command git clone #{url} #{repo_path})
  end
  private :install_or_update_repo

  def install_or_update
    install_or_update_repo('rbenv', target, URL)

    plugin_path = target.join('plugins')
    plugin_path.mkpath

    Plugins.each { |name, url|
      install_or_update_repo(name, plugin_path.join(name), url)
    }
  end
  private :install_or_update

  URL = "git://github.com/sstephenson/rbenv.git"
  Plugins = {
    "ruby-build"    => "git://github.com/sstephenson/ruby-build.git",
    "rbenv-bundler" => "git://github.com/carsomyr/rbenv-bundler.git",
    "rbenv-each"    => "git://github.com/chriseppstein/rbenv-each.git",
    "rbenv-gemset"  => "git://github.com/jamis/rbenv-gemset.git",
    "rbenv-only"    => "git://github.com/rodreegez/rbenv-only.git",
    "rbenv-update"  => "git://github.com/rkh/rbenv-update.git",
    "rbenv-use"     => "git://github.com/rkh/rbenv-use.git",
    "rbenv-vars"    => "git://github.com/sstephenson/rbenv-vars.git",
    "rbenv-whatis"  => "git://github.com/rkh/rbenv-whatis.git",
  }

  desc "Install package {{name}} (with plugins)."
  def install(task)
    install_or_update
  end

  def uninstall(task)
    fail_unless_installed
    target.rmtree
  end

  desc "Update package {{name}} (with plugins)."
  def update(task)
    install_or_update
  end
end
