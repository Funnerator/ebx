module Ebx
  module Database
    class AwsDatabase < Ebx::AwsService

      def self.build(params)
        Ebx.set_region(extract_region(params))
        case Settings[:database]['adapter']
        when 'dynamo_db'
          DynamoDb.new(params)
        else
          puts "unknown db type for #{Settings[:name]}"
        end
      end
    end
  end
end
