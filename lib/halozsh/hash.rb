# -*- ruby encoding: utf-8 -*-

class Halozsh
  class Hash
    def initialize(*args, &block)
      @data = ::Hash.new(*args, &block)
    end

    def [](key)
      return @data[key] unless is_deep_key?(key)

      key.split(/\./).inject(@data) { |m, k| m[k] }
    end

    def []=(key, value)
      return @data[key] = value unless is_deep_key?(key)

      *deep, last = key.split(/\./)

      deep.inject(@data) { |m, k| m[k] ||= self.class.new }[last] = value
    end

    def has_key?(key)
      return @data.has_key?(key) unless is_deep_key?(key)

      *deep, last = key.split(/\./)

      deep.inject(@data) { |m, k|
        return false unless m.has_key?(k)
        m[k]
      }.has_key?(last)
    end

    def delete(key)
      return @data.delete?(key) unless is_deep_key?(key)

      *deep, last = key.split(/\./)
      deep.inject(@data) { |m, k| m[k] }.delete(last)
    end

    def deep_keys
      @data.map { |k, v|
        case v
        when ::Hash
          dv = self.class.new
          dv.merge!(v)
          dv.deep_keys.map { |dk| "#{k}.#{dk}" }
        when Halozsh::Hash
          v.deep_keys.map { |dk| "#{k}.#{dk}" }
        else
          k
        end
      }.flatten
    end

    def respond_to?(name, include_private = false)
      super || @data.respond_to?(name, include_private)
    end

    def method_missing(name, *args, &block)
      if @data.respond_to?(name)
        @data.__send__(name, *args, &block)
      else
        super
      end
    end

    private
    def is_deep_key?(key)
      key =~ /\./
    end
  end
end
