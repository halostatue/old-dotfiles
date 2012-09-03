# -*- ruby encoding: utf-8 -*-

require 'halostatue'
require 'pathname'
require 'erb'

class Halostatue::Package
  include Rake::DSL

  # These methods define the Package interface, for use in a Rakefile or
  # Rake task builder.
  class << self
    include Rake::DSL

    def inherited(subclass)
      known_packages << subclass
    end

    # Returns the known packages
    def known_packages
      @known_packages ||= []
    end

    # Returns the loadable packages
    def loadable_packages(source_path)
      unless @loadable_packages
        file = Pathname.new(__FILE__)
        path = file.dirname.join(file.basename(file.extname))
        relp = path.relative_path_from(source_path)

        @loadable_packages = path.children(false).map { |child|
          next unless child.extname == '.rb'
          relp.join(child.basename(child.extname)).to_path
        }.compact
      end

      @loadable_packages
    end

    def installed_packages(installer)
      list = installer.packages_path('installed')
      if list.exist?
        [ list, list.binread.split($/) ]
      else
        [ list, [] ]
      end
    end

    # Supported package methods.
    def package_methods
      %W(install update uninstall)
    end

    # Validates the package name; mostly checks to make sure that the name
    # isn't a reserved name ("all" or "defaults").
    def validate_name!(name)
      case name
      when 'all', 'defaults'
        raise "Invalid name: must not be 'all' or 'defaults'."
      end
    end

    # Defines packaging tasks. This stuff should be defined once and
    # typically done prior to defining any individual package tasks.
    def default_package_tasks(installer, source_path = nil)
      return unless self.eql? Halostatue::Package
      return if @defined

      @defined = true
      source_path ||= installer.source_file('lib')

      packages_path = installer.packages_path.to_path
      directory packages_path

      namespace :package do
        package_methods.each do |m|
          ns = namespace(m) {}
          desc "#{m.to_s.capitalize} the named package."
          task m, [ :name ] => packages_path do |t, args|
            ns[args.name].invoke
          end
        end

        install_ns = namespace(:install) {}

        desc "Show the known packages and their state."
        task :known do
          _ , have = Halostatue::Package.installed_packages(installer)

          pkgs = install_ns.tasks.map { |pkg|
            name = pkg.name.split(/:/).last

            if name == 'all' or name == 'defaults'
              nil
            elsif have.include? name
              "  * #{name}"
            else
              "    #{name}"
            end
          }.compact!

          puts "Known packages: (* indicates the package is installed)"
          puts pkgs.join("\n")
        end
      end

      Halostatue::Package::Generator.define_generator_tasks(installer)
      define_package_task(installer, *self.loadable_packages(source_path))
    end

    def define_package_task(installer, *packages)
      return unless self.eql? Halostatue::Package

      packages.flatten.each do |package|
        case package
        when Class
          package.define_tasks(installer)
        when String
          known_packages = Halostatue::Package.known_packages.dup

          begin
            require package
          rescue LoadError
            warn "Error loading #{package}"
            next
          end

          new_packages = Halostatue::Package.known_packages - known_packages
          new_packages.each { |pkg| pkg.define_tasks(installer) }
        end
      end
    end

    # Defines package tasks.
    def define_tasks(installer)
      package = new(installer)
      raise ArgumentError, "Package is not named" unless package.name
      raise ArgumentError, "Package can't be installed" unless package.respond_to? :install
      raise ArgumentError, "Package can't be uninstalled" unless package.respond_to? :uninstall
      raise ArgumentError, "Package can't be updated" unless package.respond_to? :update

      packages_path = installer.packages_path.to_path
      directory packages_path

      package_task = package.task_name
      package_methods = %W(install update uninstall)
      namespace :package do
        package_methods.each do |m|
          namespace m do
            depends = [ dependencies, packages_path ].flatten
            task package_task => depends do |t|
              package.send(m, t)
              package.update_package_list(m)
            end

            desc "#{m.to_s.capitalize} all packages."
            task "all".to_sym => "package:#{m}:#{package_task}"
          end
        end
      end

      if default_package?
        namespace :package do
          namespace :install do
            desc "Install default packages."
            task :defaults => "package:install:#{package.name}"
          end
        end
      end
    end
  end

  # These methods define the Package DSL.
  class << self
    def name(package = nil)
      @name = package if package
      @name ||= self.to_s.split(/::/).last.downcase
      Halostatue::Package.validate_name!(@name)
      @name
    end

    def path(path = nil)
      @path = path if path
      @path || name
    end

    def default_package
      @default_package = true
    end

    def default_package?
      @default_package
    end

    def dependency(dep)
      dependencies << dep
    end

    def dependencies(deps = nil)
      @dependencies ||= []
      @dependencies << deps if deps
      @dependencies
    end

    def private_package
      @private_package = true
    end

    def private_package?
      @private_package
    end
  end

  def initialize(installer)
    @installer = installer
    @descriptions = { }

    path = Pathname.new(self.path)

    @target = if path.absolute?
                path
              else
                installer.packages_path(path)
              end
  end

  # The DotfileInstaller instance used.
  attr_reader :installer
  # The target path for installation.
  attr_reader :target

  def name
    self.class.name
  end

  def path
    self.class.path
  end

  def task_name
    name.to_sym
  end

  def update_package_list(action)
    list, data = Halostatue::Package.installed_packages(installer)

    case action.to_s
    when "install"
      data << name
      data.uniq!
    when "uninstall"
      data.delete_if { |item| name == item }
    end

    File.open(list, 'wb') { |f| f.puts data.sort.join("\n") }
  end

  def installed?
    target.directory?
  end

  def fail_if_installed
    raise "#{name} already installed in #{target}." if installed?
  end

  def fail_unless_installed
    raise "#{name} is not installed in #{target}." unless installed?
  end

  module GitPackage
    def self.included(mod)
      mod.extend(DSL)
    end

    module DSL
      def url(value = nil)
        @url = value if value
        @url or raise "No URL provided for a GitPackage."
      end
    end

    def url
      self.class.url
    end
    private :url

    def install(task)
      if installed?
        Dir.chdir(target) { sh %Q(git pull) }
      else
        pre_install(task) if respond_to?(:pre_install, true)
        sh %Q(git clone #{url} #{target})
        post_install(task) if respond_to?(:post_install, true)
      end
    end

    def uninstall(task)
      pre_uninstall(task) if respond_to?(:pre_uninstall, true)
      fail_unless_installed
      target.rmtree
      post_uninstall(task) if respond_to?(:post_uninstall, true)
    end

    def update(task)
      pre_update(task) if respond_to?(:pre_update, true)
      install(task)
      post_update(task) if respond_to?(:post_update, true)
    end
  end

  module HgPackage
    def self.included(mod)
      mod.extend(DSL)
    end

    module DSL
      def url(value = nil)
        @url = value if value
        @url or raise "No URL provided for a HgPackage."
      end
    end

    def url
      self.class.url
    end
    private :url

    def install(task)
      if installed?
        Dir.chdir(target) { sh %Q(hg pull && hg update) }
      else
        pre_install(task) if respond_to?(:pre_install, true)
        sh %Q(hg clone #{url} #{target})
        post_install(task) if respond_to?(:post_install, true)
      end
    end

    def uninstall(task)
      pre_uninstall(task) if respond_to?(:pre_uninstall, true)
      fail_unless_installed
      target.rmtree
      post_uninstall(task) if respond_to?(:post_uninstall, true)
    end

    def update(task)
      pre_update(task) if respond_to?(:pre_update, true)
      install(task)
      post_update(task) if respond_to?(:post_update, true)
    end
  end

  class Generator
    include Rake::DSL

    class << self
      include Rake::DSL

      def inherited(subclass)
        known_generators << subclass
      end

      def known_generators
        @known_generators ||= []
      end

      def define_generator_tasks(installer)
        namespace :package do
          generate = namespace :generate do
            known_generators.each do |subclass|
              generator = subclass.new(installer)

              task generator.task_name, [ :name, :url ] do |t, args|
                generator.create(t, args)
              end
            end

          end

          desc "Generate a package for 'type'."
          task :generate, [ :type, :name, :url ] do |t, args|
            generate[args.type].invoke(*args.values_at(:name, :url))
          end
        end
      end
    end

    class << self
      def name(package = nil)
        @name = package if package
        @name ||= self.to_s.split(/::/).last.downcase
        @name &&= @name.downcase
        Halostatue::Package.validate_name!(@name)
        @name
      end
    end

    def initialize(installer)
      @installer = installer
    end

    attr_reader :installer

    def name
      self.class.name
    end

    def task_name
      name.to_sym
    end

    def path(*args)
      installer.source_file(*%W(lib halostatue package)).join(*args)
    end

    def create(t, args)
      raise "Expected a package name." if args.name.nil?
      source_file = path("#{args.name.downcase}.rb")

      raise "Package #{args.name} already exists." if source_file.exist?

      klass_name = args.name.capitalize
      url = args.url || ENV['url'] || '<url>'

      tmpl = ERB.new(template, 0, '%<>')

      File.open(source_file, "w") { |f| f.write(tmpl.result(binding)) }
    end

    class Git < self
      def template
        <<-EOS
# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::<%= klass_name %> < Halostatue::Package
  include Halostatue::Package::GitPackage

  url "<%= url %>"
end
    EOS
      end
    end

    class Hg < self
      def template
        <<-EOS
# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::<%= klass_name %> < Halostatue::Package
  include Halostatue::Package::HgPackage

  url "<%= url %>"
end
    EOS
      end
    end
  end
end
