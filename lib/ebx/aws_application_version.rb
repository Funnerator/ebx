module Ebx
  class AwsApplicationVersion

    def create
      begin
        if !exists?
          puts "Creating version #{Settings.get(:version)}"
          AWS.elastic_beanstalk.client.create_application_version(
            Settings.aws_params(:name, :version, :s3_bucket, :s3_key)
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
        aws_desc = AWS.elastic_beanstalk.client.describe_application_versions(
          application_name: Settings.get(:name),
          version_labels: [Settings.get(:version)]
        )[:application_versions].first

        Settings.aws_settings_to_ebx(:application_version, aws_desc)
      end
    end
  end
end
