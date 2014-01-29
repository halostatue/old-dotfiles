# -*- ruby encoding: utf-8 -*-

require 'fileutils'
require 'pathname'
require 'erb'

begin
  require 'psych'
rescue LoadError
end
require 'yaml'

unless Pathname.public_instance_methods.include? :to_path
  class Pathname
    alias_method :to_path, :to_s

    def binread(*args)
      File.open(self.to_path, "rb") { |f| f.read(*args) }
    end
  end
end

unless IO.respond_to? :binread
  def IO.binread(fname)
    Kernel.open(fname, 'rb') { |f| f.read }
  end
end

class Halozsh
  include Rake::DSL

  module NullOps
    class << self
      def method_missing(sym, *args, &block)
        puts "noop: #{sym} #{args.join(' ')}"
      end
    end
  end

  KNOWN_USER_DATA = {
    "name"          => "Name",
    "email"         => "Email",
    "github_user"   => "GitHub User",
  }

  attr_reader :source_path
  attr_reader :target_path
  attr_reader :config_map

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

  def self.install_tasks(options = {})
    source_path = options.fetch(:source) { raise "No source provided." }
    target_path = options.fetch(:target) { raise "No target provided." }

    installer = new(source_path, target_path)
    installer.define_default_tasks
    installer.define_tasks_for(%W(zlogin zsh zshrc))
    # Something broke here.
    installer.fix_prerequisites!
  end

  def initialize(source_path, target_path)
    @source_path = Pathname.new(source_path).expand_path
    @target_path = Pathname.new(target_path).expand_path

    self.noop        = false
    self.replace_all = false

    @prerequisites   = {}
    @needs_merge     = {}
    @ostype          = %x(uname).chomp.downcase

    map_file         = source_file('config_map.yml')
    @config_map      = YAML.load(map_file.binread) if map_file.exist?
    @config_map      = {} unless @config_map.kind_of? Hash
  end

  # Returns a complete path to the packages directory.
  def packages_file(*args)
    @packages_file ||= source_file('packages')
    @packages_file.join(*args)
  end

  # Returns a complete path to a config file.
  def config_file(*args)
    @config_file ||= source_file('config')
    @config_file.join(*args)
  end

  # Returns a complete path to a user file.
  def user_file(*args)
    @user_file ||= source_file('user')
    @user_file.join(*args)
  end

  # Returns the complete path to the user data file.
  def user_data_file
    @user_data_file ||= user_file('data.yml')
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

  def ask_user_data(key)
    message = KNOWN_USER_DATA[key] || key
    user_data[key] = ask("#{message}: ") { |q| q.default = user_data[key] }
  end

  # Defines the default dotfile installation tasks.
  def define_default_tasks
    Rake::TaskManager.record_task_metadata = true

    desc "Install dotfiles into user's home directory."
    task :install

    desc "Turn all operations into noops. Does nothing on its own."
    task(:noop) { self.noop = true }

    desc "Force operations. Does nothing on its own."
    task(:force) { self.replace_all = true }

    directory user_file.to_path
    file user_data_file.to_path => user_file do |t|
      touch t.name
    end

    highline_lib = source_file("packages/highline/lib/highline/import.rb")
    file highline_lib => 'package:install:highline'

    desc "Set up the user data."
    task :setup => [ user_data_file, highline_lib ] do |t, args|
      require 'highline/import'
      KNOWN_USER_DATA.keys.each { |key|
        ask_user_data(key)
      }

      (user_data.keys - KNOWN_USER_DATA.keys).each { |key|
        ask_user_data(key)
      }

      puts

      while agree("Add additional data? ") { |q| q.default = 'n' } do
        key = ask("Enter new key name: ")

        if key.nil? or key.empty?
          puts "No key provided. Aborting."
          break
        else
          ask_user_data(key)
        end
      end

      user_data.keys.each { |key|
        value = user_data[key]
        user_data.delete(key) if value.nil? or value.empty?
      }

      puts "\n%-20s     %-40s" % %W(Key Value)
      puts "--------------------     ----------------------------------------"
      user_data.keys.each { |key|
        puts "%-20s     %-40s" % [ key, user_data[key] ]
      }

      puts
      if agree("Save this data? ")
        write_user_data
        puts "Saved."
      else
        puts "Not saved."
      end
    end

    task :default do |t|
      t.application.options.show_tasks = :tasks
      t.application.options.show_task_pattern = %r{}
      t.application.display_tasks_and_comments
    end

    Halozsh::Package.default_package_tasks(self)

    define_tasks_for(config_file.children)
  end

  # Define an installable "package". This creates a task namespace
  # equivalent to the name of the package.
  def define_package(*packages)
    Halozsh::Package.define_package_tasks(self, *packages)
  end

  # Define a task for installing the target from the source.
  def define_task(source, target)
    pre = prerequisites(source)

    file(source) { touch source } unless File.exist? source

    file target => pre do |task|
      self.try_replace_file(task.prerequisites.first, task.name)
    end
    task :install => [ target ]

    unless target.dirname == target_path
      directory target.dirname.to_path
      file target => target.dirname.to_path
    end

    if pre.size > 1 or @needs_merge[source.to_path]
      top = %x(git rev-parse --show-cdup).chomp rescue ""
      top = File.expand_path(File.join(Dir.pwd, top))

      target_name, *names = [ target, *pre ].map { |f|
        f.sub(%r{^#{Regexp.escape(top)}/?}, '').
          sub(%r{^#{Regexp.escape(ENV['HOME'])}/?}, '~/')
      }

      tword = "template"
      tword << "s" if names.size > 1
      text = "Creates #{target_name} by evaluating the ERB #{tword} in #{names.join(", ")}."

      namespace :file do
        desc text
        task File.basename(names.first).to_sym => [ target ]
      end
    end
  end

  # Define tasks for source files in the +filelist+. This will iterate over
  # the +filelist+ so that each file has a task defined such that:
  #   define_task source_file(file), target_file(".#{basename(file)}")
  # Thus:
  #   define_tasks_for %W(gitconfig gitignore)
  # is the same as calling:
  #   define_task source_file("gitconfig"), target_file(".gitconfig")
  #   define_task source_file("gitignore"), target_file(".gitignore")
  def define_tasks_for(filelist)
    filelist.each do |file|
      file = Pathname.new(file)
      next if file.basename.to_path =~ %r{^\.}

      lookup = file.relative_path_from(source_path).to_path rescue nil

      if config_map.has_key? lookup
        define_task source_file(file), target_file(config_map[lookup])
      else
        define_task source_file(file), target_file(".#{file.basename}")
      end
    end
  end

  PLATFORM_RE            = %r{\{PLATFORM\}}
  CURRENT_FILE_RE        = %r{\{FILE\}}
  PLATFORM_FILES_RE      = %r{\bplatform_files\b}
  USER_FILES_RE          = %r{\buser_files\b}
  TEMPLATE_MATCH_RE      = %r{<%=?.*?%>}m
  INCLUDE_FILE_RE        = %r{
    <%=?.*?
    (?:
     include_files?
     (?:
      \s+"(.+?)"
      |
      \s+'(.+?)'
      |
      \("(.+?)"\)
      |
      \('(.+?)'\)
      |
      ((?:platform|user)_files)
     )
     |
     include_((?:platform|user)_files)
    )
    .*?%>}mx
  USER_DATA_REFERENCE_RE = %r{<%=?.*user_data\[.*?%>}m

  def prerequisites(filename)
    filename = filename.to_s
    unless @prerequisites.has_key? filename
      @prerequisites[filename] = [ filename ]
      if File.file? filename
        data = IO.binread(filename)

        unless @needs_merge.has_key? filename
          needs_merge = !!(data =~ TEMPLATE_MATCH_RE)
          @needs_merge[filename] = needs_merge

          if needs_merge
            files = []
            files << user_data_file if data =~ USER_DATA_REFERENCE_RE

            included_files =
              data.scan(INCLUDE_FILE_RE).flatten.compact.uniq.map { |ifn|
              expand_filename_pattern(ifn, filename)
            }.flatten.compact.uniq

            included_files.each { |ifn| prerequisites(ifn) }

            files += included_files
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
    true
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
      erb = ERB.new(data, 0, "><>%")
      erb.result(binding)
    else
      puts "\t#{relative_path(filename)} (missing)…"
      ""
    end
  rescue Exception => exception
    $stderr.puts "Could not process '#{filename}': #{exception.message}"
    $stderr.puts exception.backtrace
    ""
  end

  def when_exists(path, pattern = nil)
    path = Pathname.new(path).expand_path
    if path.exist?
      pattern = yield if block_given?
      "#{pattern.gsub(%r{\{PATH\}}, path.to_s)}\n"
    else
      ""
    end
  end

  def expand_filename_pattern(filename_pattern, current_file = nil)
    fp = filename_pattern.
      gsub(PLATFORM_FILES_RE, "platform/{PLATFORM}/{FILE}").
      gsub(USER_FILES_RE, "user/**/{FILE}").
      gsub(PLATFORM_RE, @ostype).
      gsub(CURRENT_FILE_RE, File.basename(current_file || @current_file))
    Dir[fp].map { |f|
      f = Pathname.new(f).expand_path
      if f.exist?
        f
      else
        nil
      end
    }.compact.uniq
  end

  def platform_files
    "platform_files"
  end

  def include_platform_files
    include_file platform_files
  end

  def include_user_files
    include_file user_files
  end

  def user_files
    "user_files"
  end

  def include_file(filename_pattern)
    expand_filename_pattern(filename_pattern).map { |f|
      evaluate(f)
    }.join
  end
  alias_method :include_files, :include_file

  def write_user_data
    File.open(user_data_file, "wb") { |f|
      f.write user_data.to_yaml rescue ""
    }
  end
  private :write_user_data

  def read_user_data
    (YAML.load(IO.binread(user_data_file)) or {}) rescue {}
  end
  private :read_user_data

  def user_data
    @user_data ||= read_user_data
    @user_data
  end

  def merge_file(source, target)
    @current_file = File.basename(source)
    puts "Creating target #{File.basename(target)} from #{@current_file} and local files…"

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

require 'halozsh/package'

# vim: syntax=ruby