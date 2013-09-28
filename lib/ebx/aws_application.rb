module Ebx
  class AwsApplication < AwsService

    def create
      return if exists?

      puts "Creating application"
      elastic_beanstalk.client.create_application(
        Settings.aws_params(:name, :description)
      )
    end

    def exists?
      !!describe
    end

    def describe
      @description ||= begin
        aws_desc = elastic_beanstalk.client.describe_applications(
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
