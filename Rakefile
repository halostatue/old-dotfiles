# -*- ruby encoding: utf-8 -*-

DOTFILES = %w(
  boson
  zsh
  gemrc
  gitattributes
  gitconfig
  gitignore
  hgrc
  irbrc
  m2
  railsrc
  tmux.conf
  zlogin
  zshrc
  ztodolist
)

# $noop = true
SKIP_DOCS = %w(LICENSE README.md)
SKIP_DIRS = %w(.git bin include share sources vendor zshkit)
SKIP_XTRA = %w(.gitignore .gitmodules Rakefile ssh-config)

SKIP_FILES = SKIP_DOCS + SKIP_DIRS + SKIP_XTRA

class DotfileInstaller
  module NullOps
    class << self
      def method_missing(sym, *args, &block)
        puts "@fileops.#{sym} #{args.join(', ')}"
      end
    end
  end

  def initialize(noop = $noop)
    if noop
      @fileops = NullOps
    else
      require 'fileutils'
      @fileops = FileUtils
    end
  end

  def backup_file(target)
    unless File.symlink? target
      puts "Backing up target #{File.basename(target)}..."
      @fileops.cp target, "#{target}.backup"
    end
  end

  def remove_file(target)
    if File.exist? target or File.symlink? target
      backup_file target
      puts "Removing target #{File.basename(target)}..."
      @fileops.rm target, :force => true
    end
  end

  def link_file(source, target)
    puts "Linking source #{File.basename(source)} as target #{File.basename(target)}…"
    @fileops.ln_s source, target
  end

  def merge_file(source, target, contents)
    puts "Creating target #{File.basename(target)} from #{File.basename(source)} and local files…"
    contents.gsub!(/<\.replace (.+?)>/) {
      begin
        match = "#{$&}"
        input = $1

        case input
        when /\{PLATFORM\}/
          input.gsub!(/\{PLATFORM\}/) { %x(uname).chomp.downcase }
        end

        puts "\t#{input}…"
        File.read(File.expand_path(input))
      rescue => exception
        $stderr.puts "Could not replace `#{match}`: #{exception.message}"
      ""
      end
    }
    File.open(target, 'w') { |f| f.write contents }
  end

  def replace_file(source, target)
    remove_file target

    contents = File.read(source) rescue ""
    if contents.include?('<.replace ')
      merge_file source, target, contents
    else
      link_file source, target
    end
  end

  def try_replace_file(source, target = source)
    replace = false


    if File.exist? target
      if $replace_all
        replace = true
      else
        print "Overwrite target #{File.basename(target)}? [yNaq] "
        case $stdin.gets.chomp
        when 'a'
          puts "Replacing all files."
          replace = $replace_all = true
        when 'y'
          replace = true
        when 'q'
          puts "Stopping."
          exit
        else
          puts "Skipping target #{File.basename(target)}..."
        end
      end
    else
      replace = true
    end

    replace_file(source, target) if replace
  end

  def update_ssh_config
    ssh_path = File.expand_path(File.join(ENV['HOME'], ".ssh"))
    ssh_config = File.join(ssh_path, "config")
    ssh_config_part = File.expand_path(File.join(Dir.pwd, "ssh-config"))

    if File.directory? ssh_path
      if File.exist? ssh_config
        config = File.open(ssh_config) { |f| f.read }.split($/)
        skip_line = false
        new_config = config.map { |line|
          case line
          when /^##~~~ BEGIN/
            skip_line = true
            next
          when /^##~~~ END/
            skip_line = false
            next
          end

          next if skip_line
          line
        }.compact

        new_config << File.open(ssh_config_part) { |f| f.read }.split($/)
        File.open(ssh_config, "w") { |f| f.write new_config.flatten.join("\n") }
        puts "Updated ~/.ssh/config from ssh-config."
      else
        puts "~/.ssh/config does not exist. Creating from ssh-config."
        @fileops.cp ssh_config_part, ssh_config
      end
    else
      puts "~/.ssh does not exist. Skipping update of .ssh/config."
    end
  end
end

desc "Install dot files into user's home directory."
task :install

installer = DotfileInstaller.new($noop)

DOTFILES.each do |file|
  source = File.expand_path(File.join(Dir.pwd, file))
  target = File.expand_path(File.join(ENV['HOME'], ".#{file}"))

  file target => [ source ] do |task|
    installer.try_replace_file(task.prerequisites.first, task.name)
  end
  task :install => [ target ]
end

# TODO: Fix this to act like the include mechanisms for hgrc and gitrc.
# update_ssh_config

task :default do
  Rake.application.tasks.each { |t|
    puts "rake #{t.name}  # #{t.comment}" unless t.comment.to_s.empty?
  }
end

# vim: syntax=ruby
