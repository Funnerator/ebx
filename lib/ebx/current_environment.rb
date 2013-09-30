module Ebx
  class CurrentEnvironment < AwsEnvironment

    def self.master
      self.new(region: Settings.master_region)
    end

    def initialize(params)
      super
      @id = find_running[:environment_id]
    end

    private

    def find_running
      environments = elastic_beanstalk.client.describe_environments(
        Settings.aws_params(:name)
      )[:environments]
      aws_desc = environments.find {|e| e[:status] != 'Terminated' }

      @description = Settings.aws_settings_to_ebx(:environment, aws_desc)
    end
  end
end
