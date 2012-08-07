# -*- ruby encoding: utf-8 -*-

require 'halostatue'

class Halostatue::Package
  include Rake::DSL

  class << self
    include Rake::DSL

    def name(package = nil)
      @name = package if package
      @name
    end

    def path(path = nil)
      @path = path if path
      @path || name
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

      packages_path = installer.packages_path.to_path
      directory packages_path

      namespace package.task_name do
        package.public_methods(false).each do |m|
          d = descriptions[m]
          d ||= "#{m.to_s.capitalize} package {{name}}."
          d.gsub!(/\{\{name\}\}/, package.name)
          desc d
          task m => packages_path do |t|
            package.send(m, t)
            package.update_package_list(m)
          end
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
