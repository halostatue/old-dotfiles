# -*- ruby encoding: utf-8 -*-

class Halozsh
  module Common
    include Rake::DSL

    attr_reader :source_path
    attr_reader :target_path

    # Returns a complete path to a source file prepended with source_path
    def source_file(*args)
      @source_path.join(*args)
    end

    # Returns a complete path to a target file prepended with target_file
    def target_file(*args)
      @target_path.join(*args)
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

    def user_data
      unless @user_data
        @user_data = Halozsh::Hash.new
        @user_data.merge!(read_user_data)
      end
      @user_data
    end

    private
    def configure(source_path, target_path)
      @source_path = Pathname.new(source_path).expand_path
      @target_path = Pathname.new(target_path).expand_path
    end

    def read_user_data
      (YAML.load(IO.binread(user_data_file)) or {}) rescue {}
    end
  end
end
