# -*- ruby encoding: utf-8 -*-

require 'fileutils'

$noop = nil

CURRENT_PATH = File.expand_path(File.dirname(__FILE__))

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

SKIP_DOCS = %w(LICENSE README.md default_gems)
SKIP_DIRS = %w(.git bin include share sources vendor zshkit)
SKIP_XTRA = %w(.gitignore .gitmodules Rakefile ssh-config)

SKIP_FILES = SKIP_DOCS + SKIP_DIRS + SKIP_XTRA

class DotfileInstaller
  include Rake::DSL

  module NullOps
    class << self
      def method_missing(sym, *args, &block)
        puts "#{sym} #{args.join(' ')}"
      end
    end
  end

  REPLACE_MATCH_RE = %r{<\.replace (.+?)>}

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
    @needs_merge   = { }
    @replace_all = false
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
      @prerequisites[filename] = [ filename ]
      unless File.directory? filename
        files = File.open(filename) { |f| f.read }
        files = files.scan(REPLACE_MATCH_RE).flatten

        unless files.empty?
          @needs_merge[filename] = true
          files.map! { |file|
            file.gsub!(/\{PLATFORM\}/, @ostype)
            file = File.expand_path(file)
            if File.exist? file
              file
            else
              nil
            end
          }
          @prerequisites[filename] += files.compact
        end
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
    contents.gsub!(REPLACE_MATCH_RE) {
      begin
        match = "#{$&}"
        input = $1

        case input
        when /\{PLATFORM\}/
          input.gsub!(/\{PLATFORM\}/) { %x(uname).chomp.downcase }
        end

        full = File.expand_path(input)
        if File.exist? full
          puts "\t#{input}…"
          File.read(full)
        else
          puts "\t#{input} (missing)…"
          ""
        end
      rescue => exception
        $stderr.puts "Could not replace `#{match}`: #{exception.message}"
        ""
      end
    }
    File.open(target, 'w') { |f| f.write contents } unless @noop
  end

  def replace_file(source, target)
    remove_file target

    if @prerequisites[source].size > 1 or @needs_merge[source]
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
        tn = File.join(File.basename(File.dirname(target)),
                       File.basename(target))
        print "Overwrite target #{tn}? [y/N/a/q] "
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

installer = DotfileInstaller.new(CURRENT_PATH,
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

namespace :git do
  namespace :submodule do
    task :init do |t|
      Dir.chdir(CURRENT_PATH) do
        sh %Q(git submodule init)
      end
    end

    task :update do |t|
      Dir.chdir(CURRENT_PATH) do
        sh %Q(git submodule update)
      end
    end

    task :pull do |t|
      Dir.chdir(CURRENT_PATH) do
        sh %Q(git submodule foreach git pull origin master)
      end
    end
  end
end

# Something broke here.
Rake.application.tasks.each { |t|
  t.prerequisites.map! { |f|
    if f =~ /\~/
      File.expand_path(f)
    else
      f
    end
  }
}

# vim: syntax=ruby
