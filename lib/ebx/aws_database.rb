require 'ebx/database/dynamo_db'

module Ebx
  class AwsDatabase < AwsService
    def self.build(params)
      Ebx.set_region(self.class.extract_region(params))
      binding.pry
    end
  end
end
