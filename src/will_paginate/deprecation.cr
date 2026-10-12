module WillPaginate
  module Deprecation
    def self.warn(message : String) : Nil
      STDERR.puts "DEPRECATION WARNING: #{message}"
    end

    # Порт Deprecation::Hash: хэш, ключи которого можно пометить
    # устаревшими (`deprecate_key`); запись в такой ключ печатает warning.
    class Hash(K, V) < ::Hash(K, V)
      @deprecated = {} of K => (String | Proc(K, V, String | Nil))

      def initialize
        super
      end

      def []=(key : K, value : V)
        check_deprecated(key, value)
        super
      end

      def deprecate_key(*keys : K, &message : K, V -> String | Nil)
        keys.each { |key| @deprecated[key] = message }
      end

      def deprecate_key(*keys : K, message : String)
        keys.each { |key| @deprecated[key] = message }
      end

      private def check_deprecated(key : K, value : V)
        if msg = @deprecated[key]?
          msg = msg.is_a?(String) ? msg : msg.call(key, value)
          Deprecation.warn(msg) if msg
        end
      end
    end
  end
end
