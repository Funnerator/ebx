require 'ebx/aws_database'

module Ebx
  class DatabaseGroup
    attr_accessor :environments

    def initialize(environments)
      @environments = environments
      @databases = @environments.map { |e| Database::AwsDatabase.new(e) }
    end

    def self.boot
      @databases.each {|db| db.boot }
    end

  end
end
