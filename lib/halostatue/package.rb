# -*- ruby encoding: utf-8 -*-

require 'halostatue'
require 'pathname'
require 'erb'

class Halostatue::Package
  include Rake::DSL

  # These methods define the Package interface.
  class << self
    include Rake::DSL

    def inherited(subclass)
      known_packages << subclass
    end

    def known_packages
      @known_packages ||= []
    end

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

    def define_tasks(installer)
      package = new(installer)
      raise ArgumentError, "Package is not named" unless package.name
      raise ArgumentError, "Package can't be installed" unless package.respond_to? :install
      raise ArgumentError, "Package can't be uninstalled" unless package.respond_to? :uninstall
      raise ArgumentError, "Package can't be updated" unless package.respond_to? :update

      packages_path = installer.packages_path.to_path
      package_task = package.task_name
      package_methods = package.public_methods -
        Halostatue::Package.public_instance_methods

      namespace :package do
        package_methods.each do |m|
          namespace m do
            d = descriptions[m]
            d ||= "#{m.to_s.capitalize} package {{name}}."
            d.gsub!(/\{\{name\}\}/, package.name)
            desc d unless d.empty? or private_package?
            depends = [ dependencies, packages_path ].flatten
            task package_task => depends do |t|
              package.send(m, t)
              package.update_package_list(m)
            end
          end

          desc "#{m.to_s.capitalize} all packages."
          task m => "package:#{m}:#{package_task}"
        end
      end

      if default_package?
        namespace :package do
          desc "Install default packages."
          task :install_defaults => "package:install:#{package.name}"
        end
      end
    end
  end

  # These methods define the Package DSL.
  class << self
    def name(package = nil)
      @name = package if package
      @name ||= self.to_s.split(/::/).last.downcase
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

    def descriptions
      @descriptions ||= {}
    end

    def description(m, text)
      descriptions[m] = text
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
    list = installer.packages_path('installed')
    data = if list.exist?
             list.binread.split($/)
           else
             []
           end

    case action
    when :install
      data << name
      data.uniq!
    when :uninstall
      data.delete_if { |item| name == item }
    end

    File.open(list, 'wb') { |f| f.puts data.join("\n") }
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
end

class Halostatue::Package::Generator
  include Rake::DSL

  class << self
    include Rake::DSL

    def inherited(subclass)
      known_generators << subclass
    end

    def known_generators
      @known_generators ||= []
    end

    def define_tasks(installer)
      known_generators.each do |subclass|
        generator = subclass.new(installer)

        namespace :generate do
          namespace :package do
            desc generator.description if generator.description
            task generator.task_name, [ :name, :url ] do |t, args|
              generator.create(t, args)
            end
          end
        end
      end
    end
  end

  class << self
    def name(package = nil)
      @name = package if package
      @name ||= self.to_s.split(/::/).last.downcase
      @name &&= @name.downcase
      @name
    end

    def description(text = nil)
      @description = text if text
      @description ||= "Generates a #{name}-style package"
      @description
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

  def description
    self.class.description
  end

  def path(*args)
    installer.source_file(*%W(lib halostatue package)).join(*args)
  end

  def create(t, args)
    source_file = path("#{args.name.downcase}.rb")

    raise "Package #{args.name} already exists." if source_file.exist?

    klass_name = args.name.capitalize
    url = args.url || ENV['url'] || '<url>'

    tmpl = ERB.new(template, 0, '%<>')

    File.open(source_file, "w") { |f| f.write(tmpl.result(binding)) }
  end
end

class Halostatue::Package::Generator::Git < Halostatue::Package::Generator
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

class Halostatue::Package::Generator::Hg < Halostatue::Package::Generator
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
