module Ebx
  class AwsApplication

    def create
      begin
        if !exists?
          puts "Creating application"
          Aws.elastic_beanstalk.client.create_application(
            application_name: Settings.get(:name),
            description: Settings.get(:name)
          )
        end
      rescue Exception
        raise $! # TODO
      end
    end

    def exists?
      !!describe
    end

    def describe
      AWS.elastic_beanstalk.client.describe_applications(
        application_names: [Settings.get(:name)]
      ).data[:applications].first
    end
  end
end
