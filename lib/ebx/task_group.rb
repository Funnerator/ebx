require 'task'

module Ebx
  class TaskGroup
    def initialize
      binding.pry
    end

    def task_file_list
      Dir.entries(File.expand_path("../../.ebextensions"))
    end
  end
end
