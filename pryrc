#!/usr/bin/env ruby

rubyrc = File.expand_path('../.rubyrc', __FILE__)
if File.exist? rubyrc
  load rubyrc
  include RubyRC
end

if defined? ::RubyRC
  Pry.config.prompt = [
    proc { PROMPT.call(">>") },
    proc { PROMPT.call(" *") }
  ]
end
