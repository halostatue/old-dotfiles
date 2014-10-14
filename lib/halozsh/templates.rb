# -*- ruby encoding: utf-8 -*-

require 'erb'

begin
  require 'psych'
rescue LoadError
  nil
end
require 'yaml'
