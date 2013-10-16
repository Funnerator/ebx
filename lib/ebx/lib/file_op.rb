module Ebx
  module FileOp
    extend self

    def create_dir(name)
      dir = File.expand_path(name, Dir.pwd)

      raise "#{name} exists and is not a directory" if FileTest.file?(dir)
      unless FileTest.directory?(dir)
        Dir.mkdir(dir)
      end
    end
  end
end
