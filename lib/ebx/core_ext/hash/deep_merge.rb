# File activesupport/lib/active_support/core_ext/hash/deep_merge.rb, line 7
class Hash
  def deep_merge(other_hash)
    self.merge(other_hash) do |key, oldval, newval|
      oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
      newval = newval.to_hash if newval.respond_to?(:to_hash)
      oldval.class.to_s == 'Hash' && newval.class.to_s == 'Hash' ? oldval.deep_merge(newval) : newval
    end
  end

  def deep_diff(other_hash)
    r = {}

    other_hash.each do |k, v|
      if !self[k] || !(self[k].is_a?(v.class))
        r[k] = v
      elsif v.is_a?(Hash)
        diff = self[k].deep_diff(v)
        r[k] = diff if !diff.empty?
      elsif v != self[k]
        r[k] = v
      end
    end

    r
  end
end
