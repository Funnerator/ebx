class Object
  # File activesupport/lib/active_support/core_ext/object/deep_dup.rb, line 41
  def deep_dup
    each_with_object(dup) do |(key, value), hash|
      hash[key.deep_dup] = value.deep_dup
    end
  end
end
