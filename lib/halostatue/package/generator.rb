# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'erb'

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
            task generator.task_name, [ :name ] do |t, args|
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
