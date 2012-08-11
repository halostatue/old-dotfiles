# -*- ruby encoding: utf-8 -*-

require 'halostatue'
require 'pathname'

class Halostatue::Package
  include Rake::DSL

  class << self
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

    def inherited(subclass)
      known_packages << subclass
    end

    def known_packages
      @known_packages ||= []
    end

    def packages_with_tasks
      @packages_with_tasks ||= []
    end

    include Rake::DSL

    def name(package = nil)
      @name = package if package
      @name ||= self.to_s.split(/::/).last.downcase
      @name
    end

    def path(path = nil)
      @path = path if path
      @path || name
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

    def define_tasks(installer)
      package = new(installer)
      raise ArgumentError, "Package is not named" unless package.name
      raise ArgumentError, "Package can't be installed" unless package.respond_to? :install
      raise ArgumentError, "Package can't be uninstalled" unless package.respond_to? :uninstall
      raise ArgumentError, "Package can't be updated" unless package.respond_to? :update

      packages_path = installer.packages_path.to_path
      package_task = package.task_name

      namespace :package do
        package.public_methods(false).each do |m|
          namespace m do
            d = descriptions[m]
            d ||= "#{m.to_s.capitalize} package {{name}}."
            d.gsub!(/\{\{name\}\}/, package.name)
            desc d unless d.empty? or private_package?
            task package_task => packages_path do |t|
              package.send(m, t)
              package.update_package_list(m)
            end
          end

          desc "#{m.to_s.capitalize} all packages."
          task m => 'package:#{m}:#{package_task}'
        end
      end
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
end
