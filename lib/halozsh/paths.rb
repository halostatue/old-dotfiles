# -*- ruby encoding: utf-8 -*-

require 'fileutils'
require 'pathname'

unless Pathname.public_instance_methods.include? :to_path
  class Pathname
    alias_method :to_path, :to_s

    def binread(*args)
      File.open(self.to_path, "rb") { |f| f.read(*args) }
    end
  end
end

unless IO.respond_to? :binread
  def IO.binread(fname)
    Kernel.open(fname, 'rb') { |f| f.read }
  end
end
