module Ebx
  module Settings
    class HashCounter
      def initialize(hsh= nil)
        @hash = {}
        @global = {}

        add_hash(hsh) if hsh
      end

      def add_hash(hsh)
        hsh.each do |k, v|
          self[k] = v
        end
      end

      def []=(key, val)
        store = @hash[key] ||= []

        item = store.find { |v, c| val_eql?(v, val) || (v.is_a?(HashCounter) && val.is_a?(Hash)) }
        if val.is_a?(Hash)
          if !item
            store << item = [HashCounter.new(val), 0]
          else
            item[0].add_hash(val)
          end
        elsif !item
          store << item = [val, 0]
        end

        item[1] += 1
      end

      def global(counter)
        @hash.each do |k, vals|
          count = vals.inject(0) {|s, (_,c)| s += c }
          if count == counter
            val, c = *vals.max_by(&:last)
            @global[k] = val.is_a?(HashCounter) ? val.global_hash : val
          end
        end

        @global
      end

      def inspect
        @hash.inspect
      end

      def global_hash
        max = 0
        @hash.each do |k, vals|
          max = [max, vals.max_by(&:last)[1]].max
        end

        @hash.each do |k, vals|
          val, _ = *vals.find {|_, c| c >= (max / 2.0).ceil }
          if val
            @global[k] = val.is_a?(HashCounter) ? val.global_hash : val
          end
        end

        @global
      end

      private

      def val_eql?(val1, val2)
        return false if !(val1 === val2)
        case val1
        when Array
          return false if val1.size != val2.size
          val1.zip(val2).inject(true) {|b, (v1, v2)| b && val_eql?(v1,v2) }
        when Hash
          val1.inject(true) { |b, (k,v)| b && val_eql?(v, val2[k]) }
        else
          val1 == val2
        end
      end
    end
  end
end
