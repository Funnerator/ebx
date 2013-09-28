module Ebx
  class AwsApplicationVersion < AwsService

    def create
      if !find_by_version(Settings.get(:version))
        puts "Creating version #{Settings.get(:version)}"
        elastic_beanstalk.client.create_application_version(
          Settings.aws_params(:name, :version, :s3_bucket, :s3_key)
        )
      end
    end

    def up_to_date?
      current && current[:version] == Settings.get(:version)
    end

    def versions
      @versions ||= begin
        versions = elastic_beanstalk.client.describe_application_versions(
          application_name: Settings.get(:name)
        )[:application_versions]

        versions.map {|v| Settings.aws_settings_to_ebx(:application_version, v) }
      end
    end

    def current
      env = AwsEnvironment.new(region: region).describe
      active_version = env ? env[:version] : nil
      find_by_version(active_version)
    end

    def find_by_version(version)
      versions.find {|v| v[:version] == version }
    end
  end
end
