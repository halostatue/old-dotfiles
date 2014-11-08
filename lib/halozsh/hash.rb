# -*- ruby encoding: utf-8 -*-

class Halozsh
  class Hash
    def initialize(*args, &block)
      @data = ::Hash.new(*args, &block)
    end

    def [](key)
      deep key,
        ->(h, k) { h[k] || {} },
        ->(h, k) { h[k] }
    end

    def []=(key, value)
      deep key,
        ->(h, k) { h[k] ||= self.class.new },
        ->(h, k) { h[k] = value }
    end

    def has_key?(key)
      deep key,
        ->(h, k) { h.has_key?(k) || {} },
        ->(h, k) { h.has_key?(k) }
    end

    def delete(key)
      deep key,
        ->(h, k) { h[k] || {} },
        ->(h, k) { h.delete(k) }
    end

    def deep_keys
      @data.map { |k, v|
        case v
        when ::Hash
          self.class.new.merge(v).deep_keys.map { |dk| "#{k}.#{dk}" }
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
    def deep(key, query, action)
      *deep_key, last_key = key.split(/\./)
      action[deep_key.inject(@data, &query), last_key]
    end
  end
end
