# -*- ruby encoding: utf-8 -*-

require 'pathname'

SOURCE = Pathname.new(__FILE__).dirname
$:.unshift SOURCE.join('lib'), SOURCE.join('vendor/highline/lib')

require 'halostatue/dotfile_installer'

installer = Halostatue::DotfileInstaller.new(SOURCE, ENV['HOME'])
installer.define_default_tasks
installer.define_tasks_for(%W(
                           ackrc
                           bugzrc
                           editrc
                           gdbinit
                           gemrc
                           gitattributes
                           gitconfig
                           gitignore
                           hgrc
                           irbrc
                           m2
                           powconfig
                           pryrc
                           qwandry
                           railsrc
                           rspec
                           rubyrc
                           tmux.conf
                           zlogin
                           zsh
                           zshrc
                           ztodolist
                           ))
installer.define_task(installer.source_file('ssh-config'),
                      installer.target_file('.ssh', 'config'))

require 'halostatue/package/hgfold'
installer.define_package(Halostatue::Package::HGFold)

require 'halostatue/package/pybugz'
installer.define_package(Halostatue::Package::Pybugz)

require 'halostatue/package/rbenv'
installer.define_package(Halostatue::Package::RBenv)

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

namespace :vendor do
  desc "Update or initialize the vendored files."
  task :update do
    Dir.chdir(SOURCE.expand_path) do
      submodules = %x(git submodule status)

      if submodules.scan(/^(.)/).flatten.any? { |e| e == "-" }
        sh %Q(git submodule update --init --recursive)
      end

      sh %Q(git submodule foreach 'git fetch -mp && git checkout $(git branch -a | grep remotes/origin/HEAD | sed "s/ *remotes.origin.HEAD -> origin.//") && git pull')
    end
  end

  desc "Reset the vendored files to the desired state."
  task :reset do
    Dir.chdir(SOURCE.expand_path) do
      sh %Q(git submodule update --init --recursive)
    end
  end

  desc "Update the 'hub' git wrapper binary."
  task :update_hub => :update do
    Dir.chdir(SOURCE.join('vendor/hub').expand_path) do
      sh %Q(rake install prefix=#{SOURCE.join('zsh/plugin/git').expand_path})
    end
  end
end

# Something broke here.
installer.fix_prerequisites!

# vim: syntax=ruby
