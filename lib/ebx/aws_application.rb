module Ebx
  class AwsApplication

    def create
      begin
        if !exists?
          puts "Creating application"
          AWS.elastic_beanstalk.client.create_application(
            Settings.aws_params(:name, :description)
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
      @description ||= begin
        aws_desc = AWS.elastic_beanstalk.client.describe_applications(
          application_names: [Settings.get(:name)]
        ).data[:applications].first

        Settings.aws_settings_to_ebx(:application, aws_desc)
      end
    end

    def delete
      AWS.elastic_beanstalk.client.delete_application(
        Setting.aws_params(:name)
      )
      puts "Deleted #{Settings.get(:name)} in #{Ebx.region}"
    end
  end
end
