# -*- ruby encoding: utf-8 -*-

require 'fileutils'
require 'pathname'

module Halostatue; end

class Halostatue::DotfileInstaller
  include Rake::DSL

  module NullOps
    class << self
      def method_missing(sym, *args, &block)
        puts "noop: #{sym} #{args.join(' ')}"
      end
    end
  end

  REPLACE_MATCH_RE = %r{<\.replace (.+?)>}

  attr_reader :source_path
  attr_reader :target_path

  # Sets the operations mode.
  def noop=(value)
    @noop = !!value
    @fileops = if @noop
                 @fileops = NullOps
               else
                 @fileops = FileUtils
               end
  end
  # Returns true if the operations mode is noop (do nothing).
  def noop?
    @noop
  end

  # The file operations to be performed.
  def fileops
    @fileops
  end

  # Sets the replace-all mode.
  def replace_all=(value)
    @replace_all = !!value
  end
  # Returns true if all values are replaced.
  def replace_all?
    @replace_all
  end

  def initialize(source_path, target_path)
    @source_path = Pathname.new(source_path).expand_path
    @target_path = Pathname.new(target_path).expand_path

    self.noop = false
    self.replace_all = false

    @prerequisites = { }
    @needs_merge   = { }
    @ostype = %x(uname).chomp.downcase
  end

  # Returns a complete path to a source file prepended with source_path
  def source_file(*args)
    @source_path.join(*args)
  end

  # Returns a complete path to a target file prepended with target_file
  def target_file(*args)
    @target_path.join(*args)
  end

  # Defines the default dotfile installation tasks.
  def define_default_tasks
    Rake::TaskManager.record_task_metadata = true

    desc "Install dotfiles into user's home directory."
    task :install

    desc "Turn all operations into noops. Does nothing on its own."
    task(:noop) { self.noop = true }

    desc "Force operations. Does nothing on its own."
    task(:force) { installer.replace_all = true }

    task :default do |t|
      t.application.options.show_tasks = :tasks
      t.application.options.show_task_pattern = %r{}
      t.application.display_tasks_and_comments
    end
  end

  # Define an installable "package". This creates a task namespace
  # equivalent to the name of the package. At a minimum, a task must include
  # callable objects for the keys :install and :uninstall. Other tasks may
  # be defined by providing a hash that contains subkeys of :desc and :task;
  # these tasks will not have dependencies.
  def define_package(package, options = {})
    unless options.has_key? :install and options.has_key? :uninstall
      raise "Invalid package definition #{package}; missing install or uninstall."
    end

    namespace package.to_sym do
      options.each { |key, params|
        case key
        when :install
          desc "Install package #{package}."
          task(:install) { params.call }
        when :uninstall
          desc "Uninstall package #{package}."
          task(:uninstall) { params.call }
        else
          next unless params.kind_of? Hash and params.has_key? :task
          desc params[:desc] if params.has_key? :desc
          task_code = params[:task]
          task(key.to_sym) { task_code.call }
        end
      }
    end
  end

  # Define a task for installing the target from the soruce.
  def define_task(source, target)
    pre = prerequisites(source)

    file(source) { touch source } unless File.exist? source

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

  # Define tasks for source files in the +filelist+. This will iterate over
  # the +filelist+ so that each file has a task defined such that:
  #   define_task source_file(file), target_file(".#{file}")
  # Thus:
  #   define_tasks_for %W(gitconfig gitignore)
  # is the same as calling:
  #   define_task_for source_file("gitconfig"), target_file(".gitconfig")
  #   define_task_for source_file("gitignore"), target_file(".gitignore")
  def define_tasks_for(filelist)
    filelist.each do |file|
      define_task source_file(file), target_file(".#{file}")
    end
  end

  def prerequisites(filename)
    filename = filename.to_s
    unless @prerequisites.has_key? filename
      @prerequisites[filename] = [ filename ]
      unless File.directory? filename
        if File.exist? filename
          files = File.open(filename) { |f| f.read }
          files = files.scan(REPLACE_MATCH_RE).flatten

          unless files.empty?
            @needs_merge[filename] = true
            files.map! { |fn|
              fn.gsub!(/\{PLATFORM\}/, @ostype)
              fn = File.expand_path(fn)
              if File.exist? fn
                fn
              else
                nil
              end
            }
            @prerequisites[filename] += files.compact
          end
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
      self.fileops.mv target, "#{target}.backup"
    elsif File.file? target
      puts "Backing up target #{File.basename(target)}…"
      self.fileops.cp target, "#{target}.backup"
    else
      raise "Unknown type for #{File.basename(target)}!"
    end
  end

  def remove_file(target)
    if File.exist? target or File.symlink? target
      if backup_file target
        puts "Removing target #{File.basename(target)}…"
        self.fileops.rm target, :force => true
      end
    end
  end

  def link_file(source, target)
    puts "Linking source #{File.basename(source)} as target #{File.basename(target)}…"
    self.fileops.ln_s source, target
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
    if self.noop?
      puts "noop: #{File.basename(target)} not written."
    else
      File.open(target, 'w') { |f| f.write contents }
    end
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
      if self.replace_all?
        replace = true
      else
        tn = File.join(File.basename(File.dirname(target)),
                       File.basename(target))
        print "Overwrite target #{tn}? [y/N/a/q] "
        case $stdin.gets.chomp
        when 'a'
          puts "Replacing all files."
          replace = self.replace_all = true
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

# vim: syntax=ruby
