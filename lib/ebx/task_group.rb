require 'ebx/task'

module Ebx
  class TaskGroup

    def initialize
      @tasks = task_file_list.each {|f| Task.from_file(f) }
    end

    def task_file_list
      Dir.entries(File.expand_path(".ebextensions"))[2..-1]
    end

    def list
      @tasks.empty? ? 'No tasks defined' : @tasks.map {|t| t.to_s }
    end
  end
end
