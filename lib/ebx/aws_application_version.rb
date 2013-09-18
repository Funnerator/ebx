module Ebx
  class AwsApplicationVersion

    def create
      begin
        if describe.empty?
          puts "Creating version #{Settings.get(:version)}"
          AWS.elastic_beanstalk.client.create_application_version(
            application_name: Settings.get(:name),
            version_label: Settings.get(:version),
            source_bundle: {
              s3_bucket: Settings.get(:s3_bucket),
              s3_key: Settings.get(:s3_key)
            }
          )
        end
      rescue Exception
        raise $! # TODO
      end
    end

    def describe
      AWS.elastic_beanstalk.client.describe_application_versions(
        application_name: Settings.get(:name),
        version_labels: [Settings.get(:version)]
      )[:application_versions]
    end
  end
end
