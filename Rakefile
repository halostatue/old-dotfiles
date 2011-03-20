# -*- ruby encoding: utf-8 -*-

require 'fileutils'

DOTFILES = %w(
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

SKIP_DOCS = %w(LICENSE README.md)
SKIP_DIRS = %w(.git bin include share sources vendor zshkit)
SKIP_XTRA = %w(.gitignore .gitmodules Rakefile ssh-config)

SKIP_FILES = SKIP_DOCS + SKIP_DIRS + SKIP_XTRA

class DotfileInstaller
  module NullOps
    class << self
      def method_missing(sym, *args, &block)
        puts "#{sym} #{args.join(' ')}"
      end
    end
  end

  attr_reader :source_path
  attr_reader :target_path

  def noop(value)
    @noop = value
    @fileops = if @noop
                 @fileops = NullOps
               else
                 @fileops = FileUtils
               end
  end

  def replace_all(value)
    @replace_all = value
  end

  def initialize(source_path, target_path, options)
    @source_path = source_path
    @target_path = target_path

    noop options[:noop]

    @prerequisites = { }
    @ostype = %x(uname).chomp.downcase
  end

  def source(*args)
    File.join(@source_path, *args)
  end

  def target(*args)
    File.join(@target_path, *args)
  end

  def define_task(source, target)
    pre = prerequisites(source)

    file target => pre do |task|
      self.try_replace_file(task.prerequisites.first, task.name)
    end
    task :install => [ target ]

    if pre.size > 1
      top = %x(git rev-parse --show-cdup).chomp rescue ""
      top = File.expand_path(File.join(Dir.pwd, top))

      name, *incl = pre
      name = File.basename(name)
      incl.map! { |f|
        f.sub!(%r{^#{Regexp.escape(top)}/?}, '')
        f.sub!(%r{^#{Regexp.escape(ENV['HOME'])}/?}, '~/')
        f
      }

      namespace :file do
        desc "Includes: #{incl.join(', ')}"
        task name.to_sym => [ target ]
      end
    end
  end

  def define_tasks_for(filelist)
    filelist.each do |file|
      define_task source(file), target(".#{file}")
    end
  end

  def prerequisites(filename)
    unless @prerequisites.has_key? filename
      @prerequisites[filename] = if File.directory? filename
                               [ filename ]
                             else
                               files = File.open(filename) { |f| f.read }
                               files = files.scan(/<\.replace (.+?)>/)
                               files.flatten!
                               files.map! { |file|
                                 file.gsub!(/\{PLATFORM\}/, @ostype)
                                 file = File.expand_path(file)
                                 if File.exist? file
                                   file
                                 else
                                   nil
                                 end
                               }
                               files.unshift filename
                               files.compact!
                               files
                             end
    end

    @prerequisites[filename]
  end

  def backup_file(target)
    if File.symlink? target
      true
    elsif File.directory? target
      puts "Backing up target directory #{File.basename(target)}…"
      @fileops.mv target, "#{target}.backup"
    elsif File.file? target
      puts "Backing up target #{File.basename(target)}…"
      @fileops.cp target, "#{target}.backup"
    else
      raise "Unknown type for #{File.basename(target)}!"
    end
  end

  def remove_file(target)
    if File.exist? target or File.symlink? target
      if backup_file target
        puts "Removing target #{File.basename(target)}…"
        @fileops.rm target, :force => true
      end
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
    File.open(target, 'w') { |f| f.write contents } unless @noop
  end

  def replace_file(source, target)
    remove_file target

    if @prerequisites[source].size > 1
      contents = File.read(source) rescue ""
      merge_file source, target, contents
    else
      link_file source, target
    end
  end

  def try_replace_file(source, target = source)
    replace = false

    if File.exist? target
      if @replace_all
        replace = true
      else
        print "Overwrite target #{File.basename(target)}? [y/N/a/q] "
        case $stdin.gets.chomp
        when 'a'
          puts "Replacing all files."
          replace = @replace_all = true
        when 'y'
          replace = true
        when 'q'
          puts "Stopping."
          exit
        else
          puts "Skipping target #{File.basename(target)}…"
        end
      end
    else
      replace = true
    end

    replace_file(source, target) if replace
  end
end

desc "Install dot files into user's home directory."
task :install

installer = DotfileInstaller.new(File.expand_path(Dir.pwd),
                                 File.expand_path(ENV['HOME']),
                                :noop => $noop)

installer.define_tasks_for(DOTFILES)
installer.define_task(installer.source('ssh-config'),
                      installer.target('.ssh', 'config'))

desc "Turn all operations into noops. Does nothing on its own."
task :noop do
  installer.noop true
end

desc "Force operations. Does nothing on its own."
task :force do
  installer.replace_all true
end

task :default do
  Rake.application.tasks.each { |t|
    puts "rake #{t.name}  # #{t.comment}" unless t.comment.to_s.empty?
  }
end

# vim: syntax=ruby
