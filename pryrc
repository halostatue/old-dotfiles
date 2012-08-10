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

rescue Exception => ex
  puts ex.message
  puts ex.backtrace
end
