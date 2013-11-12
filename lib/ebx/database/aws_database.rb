require 'ebx/database/dynamo_db'

module Ebx
  module Database
    class AwsDatabase < Ebx::AwsService
      def self.build(params)
        Ebx.set_region(self.class.extract_region(params))
        binding.pry
        case Settings[:database][:adapter]
        when 'dynamo_db'
          Database::DynamoDb.new(params)
        else
          puts "unknown db type for #{Settings[:name]}"
        end
      end
    end
  end
end
