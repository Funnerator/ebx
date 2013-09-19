module Ebx
  class AwsApplication

    def create
      begin
        if !exists?
          puts "Creating application"
          AWS.elastic_beanstalk.client.create_application(
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

    def delete
      AWS.elastic_beanstalk.client.delete_application(
        application_name: Settings.get(:name)
      )
      puts "Deleted #{Settings.get(:name)} in #{Ebx.region}"
    end
  end
end
