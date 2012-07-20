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

    def descriptions
      @descriptions ||= {}
    end

    def description(f, text)
      descriptions[f] = text
    end

    def define_tasks(installer)
      package = new(installer)
      raise ArgumentError, "Package is not named" unless package.name

      namespace package.task_name do
        desc "Install package #{package.name}."
        task(:install) { |tsk| package.install(tsk) }

        desc "Uninstall package #{package.name}."
        task(:uninstall) { |tsk| package.uninstall(tsk) }

        package.public_methods(false).each { |f|
          next if f == :install
          next if f == :uninstall

          if descriptions[f]
            d = descriptions[f].gsub(/\{\{package.name\}\}/, package.name)
            desc d
          end
          task(f) { |tsk| package.__send__(f, tsk) }
        }
      end
    end
  end

  def initialize(installer)
    @installer = installer
    @descriptions = { }
  end

  attr_reader :installer

  def name
    self.class.name
  end

  def task_name
    name.to_sym
  end

  def install(task)
    raise NoMethodError, "No install method defined."
  end

  def uninstall(task)
    raise NoMethodError, "No uninstall method defined."
  end
end
