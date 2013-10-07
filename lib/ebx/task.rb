module Ebx
  class Task
    def self.from_file(path)
      Psych.load_file(path)
      filename = path[/[^\/]+$/]
      self.new(filename)
    end

    def initialize(name)

    end

    def list_name
    end
  end
end
