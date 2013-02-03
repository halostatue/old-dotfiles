# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/definition'

class Halostatue::Package::Definition::RbEnv < Halostatue::Package
  path Pathname.new('~/.rbenv').expand_path
  has_plugin

  def install_or_update_repo(name, repo_path, url)
    puts "#{name}…"

    if repo_path.directory?
      if repo_path.join(".git").directory?
        return Dir.chdir(repo_path) { sh %Q(git pull) }
      else
        warn "Protecting non-git directory as #{repo_path.basename}.bak"
        repo_path.rename("#{repo_path}.bak")
      end
    elsif repo_path.file?
      warn "Protecting non-git file as #{repo_path.basename}.bak"
      repo_path.rename("#{repo_path}.bak")
    end

    sh %Q(git clone #{url} #{repo_path})
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

  URL = "https://github.com/sstephenson/rbenv.git"
  Plugins = {
    "ruby-build"         => "https://github.com/sstephenson/ruby-build.git",
    "rbenv-default-gems" => "https://github.com/sstephenson/rbenv-default-gems.git",
    "rbenv-each"         => "https://github.com/chriseppstein/rbenv-each.git",
    "rbenv-env"          => "https://github.com/ianheggie/rbenv-env.git",
    "rbenv-gem-rehash"   => "https://github.com/sstephenson/rbenv-gem-rehash.git",
    "rbenv-gemset"       => "https://github.com/jamis/rbenv-gemset.git",
    "rbenv-only"         => "https://github.com/rodreegez/rbenv-only.git",
    "rbenv-rbx"          => "https://github.com/rmm5t/rbenv-rbx.git",
    "rbenv-update"       => "https://github.com/rkh/rbenv-update.git",
    "rbenv-use"          => "https://github.com/rkh/rbenv-use.git",
    "rbenv-vars"         => "https://github.com/sstephenson/rbenv-vars.git",
    "rbenv-whatis"       => "https://github.com/rkh/rbenv-whatis.git",
  }

  def install(task)
    install_or_update
  end

  def uninstall(task)
    fail_unless_installed
    target.rmtree
  end

  def update(task)
    install_or_update
  end

  def plugin_init_file
    <<-EOS
add-paths-after-if #{target.join('bin')}

function()
{
  local REPORTTIME=-1
  eval "$(rbenv init -)"
}
    EOS
  end
end
