class Hash

  #TODO This sucks
  def deep_dup
    Marshal.load(Marshal.dump(self))
  end
end
