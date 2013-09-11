class AwsApplicationVersion
  attr_accessor :settings

  def initialize(settings)
    @settings = settings
  end

  def create
    begin
      if describe[:application_versions].empty?
        ElasticBeanstalk.instance.client.create_application_version(
          application_name: settings['name'],
          version_label: settings['version'],
          source_bundle: {
            s3_bucket: settings['s3_bucket'],
            s3_key: settings['s3_key']
          }
        )
      end
    rescue Exception
      raise $! # TODO
    end
  end

  def describe
    ElasticBeanstalk.instance.client.describe_application_versions(
      application_name: settings['name'],
      version_labels: [settings['version']]
    )
  end
end
