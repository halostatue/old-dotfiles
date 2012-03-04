# -*- ruby encoding: utf-8 -*-

require 'fileutils'
require 'pathname'
require 'erb'

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

  TEMPLATE_MATCH_RE = %r{<%=}
  INCLUDE_FILE_RE   = %r{<%= include_file "(.+?)" %>}
  PLATFORM_RE       = %r{\{PLATFORM\}}

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

  # Rake doesn't like prerequisites that start with a tilde. Fix it. This
  # must be the last thing in the Rakefile.
  def fix_prerequisites!
    Rake.application.tasks.each { |t|
      t.prerequisites.map! { |f|
        if f =~ /\~/
          File.expand_path(f)
        else
          f
        end
      }
    }
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

    desc "Set up the user data."
    task :setup, [ :name, :email ] do |t, args|
      self.source_file("user").mkpath
      self.source_file("user", "name").open("wb") { |f| f.puts args.name }
      self.source_file("user", "email").open("wb") { |f| f.puts args.email }
    end

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
  #
  # All package task callable objects must accept two parameters: the
  # installer and the task. Task arguments are not permitted on these tasks
  # (any arguments should be passed through the environment).
  def define_package(package, options = {})
    unless options.has_key? :install and options.has_key? :uninstall
      raise "Invalid package definition #{package}; missing install or uninstall."
    end

    i = self

    namespace package.to_sym do
      options.each { |key, params|
        case key
        when :install
          desc "Install package #{package}."
          task(:install) { |t| params.call(i, t) }
        when :uninstall
          desc "Uninstall package #{package}."
          task(:uninstall) { |t| params.call(i, t) }
        when :update
          desc "Update package #{package}."
          task(:update) { |t| params.call(i, t) }
        else
          next unless params.kind_of? Hash and params.has_key? :task
          desc params[:desc] if params.has_key? :desc
          task_code = params[:task]
          task(key.to_sym) { |t| task_code.call(i, t) }
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
          data = File.open(filename) { |f| f.read }
          @needs_merge[filename] = !!(data =~ TEMPLATE_MATCH_RE)

          files = data.scan(INCLUDE_FILE_RE).flatten

          unless files.empty?
            @needs_merge[filename] = true
            files.map! { |fn|
              fn.gsub!(PLATFORM_RE, @ostype)
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

  def evaluate(filename)
    if File.exists? filename
      puts "\t#{relative_path(filename)}…"
      data = File.open(filename) { |f| f.read }
      erb = ERB.new(data, 0, "<>")
      erb.result(binding)
    else
      puts "\t#{relative_path(filename)} (missing)…"
      ""
    end
  rescue Exception => exception
    $stderr.puts "Could not process '#{filename}': #{exception.message}"
    ""
  end

  def when_exists(path, pattern)
    path = Pathname.new(path).expand_path
    if path.exist?
      "#{pattern.gsub(%r{\{PATH\}}, path.to_s)}\n"
    else
      ""
    end
  end

  def include_file(filename)
    evaluate(Pathname.new(filename.gsub(PLATFORM_RE, @ostype)).expand_path).
      chomp
  end

  def merge_file(source, target)
    puts "Creating target #{File.basename(target)} from #{File.basename(source)} and local files…"

    contents = evaluate(source)

    if self.noop?
      puts "noop: #{File.basename(target)} not written."
    else
      File.open(target, 'w') { |f| f.write contents }
    end
  end

  def replace_file(source, target)
    remove_file target

    if @prerequisites[source].size > 1 or @needs_merge[source]
      merge_file source, target
    else
      link_file source, target
    end
  end

  def relative_path(path)
    base = Pathname.new("~")
    path = Pathname.new(path)
    path = path.relative_path_from(base.expand_path)
    base.join(path)
  end

  def try_replace_file(source, target = source)
    replace = false

    if File.exist? target
      if self.replace_all?
        replace = true
      else

        print "Overwrite target #{relative_path(target)}? [y/N/a/q] "
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
