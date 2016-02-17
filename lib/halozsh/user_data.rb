# -*- ruby encoding: utf-8 -*-

class Halozsh
  class UserData
    include Common

    KNOWN_USER_DATA = {
      "name"               => "Name",
      "email"              => "Email",
      "github.user"        => "GitHub User",
      "github.oauth_token" => "GitHub OAuth Token",
      "hoe.travis_token"   => "Hoe Travis Token",
      "hoe.email.address"  => "Hoe Email Address",
      "hoe.email.password" => "Hoe Email Password"
    }

    MATCH = %r{<%=?.*user_data\[.*?%>}m

    class << self
      def define_tasks_with(installer)
        new(installer).define_tasks
      end
      private :new
    end

    def initialize(installer)
      configure(installer.source_path, installer.target_path)
    end

    def define_tasks
      directory user_file.to_path
      file user_data_file.to_path => user_file do |t|
        touch t.name
      end

      desc "Set up the user data."
      task :setup => [ user_data_file ] do |t, args|
        require 'highline/import'
        KNOWN_USER_DATA.keys.each { |key|
          ask_user_data(key)
        }

        (user_data.deep_keys - KNOWN_USER_DATA.keys).each { |key|
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

        user_data.deep_keys.each { |key|
          value = user_data[key]
          user_data.delete(key) if value.nil? or value.empty?
        }

        puts "\n%-30s  %-40s" % %W(Key Value)
        puts "--------------------  ----------------------------------------"
        user_data.deep_keys.each { |key|
          puts "%-30s  %-40s" % [ key.gsub(/\./, ' '), user_data[key] ]
        }

        puts
        if agree("Save this data? ")
          write_user_data
          puts "Saved."
        else
          puts "Not saved."
        end
      end
    end

    def ask_user_data(key)
      require 'byebug'
      debugger
      data = user_data[key]

      if data.respond_to?(:each_key)
        data.each_key { |k| ask_user_data("#{key}.#{k}") }
      else
        message = KNOWN_USER_DATA[key] || key.gsub(/\./, ' ')

        user_data[key] = ask("#{message}: ") { |q|
          q.default = user_data[key]
        }.to_s
      end
    end

    def write_user_data
      File.open(user_data_file, "wb") { |f|
        f.write user_data.to_yaml rescue ""
      }
    end
  end
end
