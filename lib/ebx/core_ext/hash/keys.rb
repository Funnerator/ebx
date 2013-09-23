# File activesupport/lib/active_support/core_ext/hash/keys.rb
class Hash
  def stringify_keys!
    keys.each do |key|
      self[key.to_s] = delete(key)
    end
    self
  end
end
