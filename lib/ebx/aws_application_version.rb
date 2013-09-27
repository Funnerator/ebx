module Ebx
  class AwsApplicationVersion

    def create
      if !current?
        puts "Creating version #{Settings.get(:version)}"
        AWS.elastic_beanstalk.client.create_application_version(
          Settings.aws_params(:name, :version, :s3_bucket, :s3_key)
        )
      end
    end

    def current?
      describe && describe[:version] == Settings.get(:version)
    end

    def describe
      @description ||= begin
        aws_desc = AWS.elastic_beanstalk.client.describe_application_versions(
          application_name: Settings.get(:name)
        )[:application_versions]
        env_desc = AwsEnvironment.new.describe
        current_version = env_desc ? env_desc[:version] : nil
        aws_desc = aws_desc.find {|a| a[:version] == current_version }

        Settings.aws_settings_to_ebx(:application_version, aws_desc)
      end
    end
  end
end
