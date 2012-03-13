# -*- ruby encoding: utf-8 -*-

require 'pathname'

SOURCE = Pathname.new(__FILE__).dirname
$:.unshift SOURCE.join('lib'), SOURCE.join('vendor/highline/lib')
puts $:

require 'halostatue-dotfile-installer'

installer = Halostatue::DotfileInstaller.new(SOURCE, ENV['HOME'])
installer.define_default_tasks
installer.define_tasks_for(%W(
                           ackrc
                           gdbinit
                           gemrc
                           gitattributes
                           gitconfig
                           gitignore
                           hgrc
                           irbrc
                           m2
                           pryrc
                           railsrc
                           rspec
                           tmux.conf
                           zlogin
                           zsh
                           zshrc
                           ztodolist
                           ))
installer.define_task(installer.source_file('ssh-config'),
                      installer.target_file('.ssh', 'config'))

hgfold_install = lambda { |i, t|
  i.source_file.join("packages").mkpath
  target = i.source_file.join("packages/hgfold")
  sh %Q(hg clone bb+ssh://bradobro/hgfold #{target})
  touch i.source_file.join("hgrc")
  Rake::Task[:install].invoke
}
hgfold_uninstall = lambda { |i, t|
  target = i.source_file.join("packages/hgfold")
  if target.directory?
    target.rmtree
    touch i.source_file.join("hgrc")
    Rake::Task[:install].invoke
  end
}
hgfold_update = lambda { |i, t|
  target = i.source_file.join("packages/hgfold")
  if target.directory?
    Dir.chdir(target) do
      sh %Q(hg pull && hg update)
      touch i.source_file.join("hgrc")
      Rake::Task[:install].invoke
    end
  end
}

installer.define_package("hgfold",
                         :install   => hgfold_install,
                         :uninstall => hgfold_uninstall,
                         :update    => hgfold_update)

namespace :gem do
  desc "Install the default gems for the environment."
  task :install => [ "default_gems" ] do |t|
    gems = []
    t.prerequisites.each { |req|
      gems += File.open(req) { |f| f.read.split($/) }
    }
    gems.each { |e|
      e.chomp!

      next if e.empty?
      next if e =~ /^\s*#/

      n, v = e.split(/\s+/, 2)

      if %x(gem list -v "#{v}" -i #{n}).chomp == 'false'
        sh %Q(gem install -v "#{v}" #{n})
      end
    }
  end
end

namespace :rbenv do
  def install_or_update_repo(target, url)
    if target.directory?
      if target.join(".git").directory?
        sh %Q(command git pull)
        return
      else
        warn "Protecting non-git directory as #{target.basename}.bak"
        target.rename("#{target}.bak")
      end
    elsif target.file?
      warn "Protecting non-git file as #{target.basename}.bak"
      target.rename("#{target}.bak")
    end

    sh %Q(command git clone #{url} #{target})
  end

  rbenv_url = "git://github.com/sstephenson/rbenv.git"
  rbenv_target = Pathname.new("~/.rbenv").expand_path
  plugins = {
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

  desc "Install package rbenv (with plugins)"
  task :install do
    install_or_update_repo(rbenv_target, rbenv_url)
    rbenv_target.join("plugins").mkpath

    plugins.each { |name, url|
      install_or_update_repo(rbenv_target.join("plugins", name), url)
    }
  end

  desc "Uninstall package rbenv"
  task :uninstall do
    rbenv_target.rmtree
  end

  desc "Update package rbenv"
  task :update => :install
end

namespace :vendor do
  desc "Update or initialize the vendored files."
  task :update do
    Dir.chdir(SOURCE.expand_path) do
      submodules = %x(git submodule status)

      if submodules.scan(/^(.)/).flatten.any? { |e| e == "-" }
        sh %Q(git submodule update --init --recursive)
      end

      sh %Q(git submodule foreach 'git pull -p origin master && git checkout master && git pull')
    end
  end

  desc "Reset the vendored files to the desired state."
  task :reset do
    Dir.chdir(SOURCE.expand_path) do
      sh %Q(git submodule update --init --recursive)
    end
  end
end

# Something broke here.
installer.fix_prerequisites!

# vim: syntax=ruby
