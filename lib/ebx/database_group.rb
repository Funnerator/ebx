require 'ebx/database/aws_database'
require 'ebx/database/dynamo_db'

module Ebx
  class DatabaseGroup
    attr_accessor :environments

    def initialize(environments)
      @environments = environments
      @databases = @environments.map { |e| Database::AwsDatabase.build(environment: e) }
    end

    def boot
      @databases.each {|db| db.boot }
    end
  end
end
