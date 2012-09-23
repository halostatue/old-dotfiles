#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

begin
  rubyrc = File.expand_path('../.rubyrc', __FILE__)
  if File.exist? rubyrc
    load rubyrc
    include RubyRC
  end

  Pry.config.editor = 'vim'

  if Pry.plugins.has_key? "debugger"
    Pry.commands.alias_command 'c', 'continue'
    Pry.commands.alias_command 's', 'step'
    Pry.commands.alias_command 'n', 'next'
    Pry.commands.alias_command 'f', 'finish'
  end

  if defined? ::RubyRC
    Pry.config.prompt = [
      proc { PROMPT.call(">>") },
      proc { PROMPT.call(" *") }
    ]
#   Pry.config.prompt = [
#     proc { |obj, nest_level, _| "#{RUBY_VERSION} (#{obj}):#{nest_level} > " },
#     proc { |obj, nest_level, _| "#{RUBY_VERSION} (#{obj}):#{nest_level} * " }
#   ]

    if ::RubyRC.rails?
      require 'logger'

      ActiveRecord::Base.logger = Logger.new(STDOUT)
      ActiveRecord::Base.clear_active_connections!

      class Class
        def core_ext
          self.instance_methods.map { |m|
            [m, self.instance_method(m).source_location] }.select { |m|
              m[1] && m[1][0] =~/activesupport/ }.map { |m|
                m[0] }.sort
        end
      end
    end
  end

  default_command_set = Pry::CommandSet.new do
    command "copy", "Copy argument to the clip-board" do |str|
      IO.popen('pbcopy', 'w') { |f| f << str.to_s }
    end

    command "clear" do
      system 'clear'
      if ENV['RAILS_ENV']
        output.puts "Rails Environment: " + ENV['RAILS_ENV']
      end
    end

    command "sql", "Send sql over AR." do |query|
      if ENV['RAILS_ENV'] || defined?(Rails)
        pp ActiveRecord::Base.connection.select_all(query)
      else
        pp "No rails env defined"
      end
    end
    command "caller_method" do |depth|
      depth = depth.to_i || 1
      if /^(.+?):(\d+)(?::in `(.*)')?/ =~ caller(depth+1).first
        file   = Regexp.last_match[1]
        line   = Regexp.last_match[2].to_i
        method = Regexp.last_match[3]
        output.puts [file, line, method]
      end
    end
  end

  Pry.config.commands.import default_command_set

rescue Exception => ex
  puts ex.message
  puts ex.backtrace
end
