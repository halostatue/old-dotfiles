# -*- ruby encoding: utf-8 -*-

require 'pathname'

SOURCE = Pathname.new(__FILE__).dirname
$:.unshift SOURCE.join('lib'), SOURCE.join('packages/highline/lib')

require 'halostatue/dotfile_installer'

Halostatue::DotfileInstaller.installer_for(SOURCE, ENV['HOME'])

namespace :gem do
  desc "Install the default gems for the environment."
  task :default => [ "default/gems" ] do |t|
    gems = t.prerequisites.map { |req| IO.readlines(req) }.flatten
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

namespace :homebrew do
  desc "Install or update the default homebrew formulas."
  task :default => [ "default/brew" ] do |t|
    kegs = %x(brew list).split($/)
    taps = %x(brew tap).split($/)
    lines = t.prerequisites.map { |req| IO.readlines(req) }.flatten

    lines.each { |line|
      line = line.chomp.gsub(/#.*$/, '').strip

      next if line.empty?

      command, part, _ = line.split(/\s+/, 3)

      case command
      when "tap"
        next if taps.include? part
      when "install"
        next if kegs.include? part
      end

      p %Q(brew #{line})
      sh %Q(brew #{line})
    }
  end
end

namespace :vendor do
  desc "Add a new vendored repository."
  task :add, [ :url, :name ] do |t, args|
    url  = args.url or raise "Need a repo URL"
    name = Pathname.new(args.name || args.url).basename('.git')
    path = Pathname.new('vendor').join(name)

    raise "Vendor path #{path} already exists." if SOURCE.join(path).exist?

    # Make vendor:add[url] act more like 'hub' and assume github.com if an
    # incomplete URL has been provided and the format is name/repo.
    url = "git://github.com/#{url}" if url =~ %r{[-\w]+/[-\w]+}

    Dir.chdir(SOURCE.expand_path) do
      sh %Q(git submodule add #{url} #{path})
      sh %Q(git submodule update --init --recursive #{path})
      sh %Q(git commit .gitmodules #{path} -m "Adding submodule #{url} as #{path}")
    end
  end

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
end

# vim: syntax=ruby
