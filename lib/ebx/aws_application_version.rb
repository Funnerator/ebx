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
          version_label: version
          #source_bundle: {
          #  s3_bucket: settings[:source_bucket],
          #  s3_key: settings[:source_key]
          #}
        )
      end
    rescue Exception
      raise $! # TODO
    end
  end

  def describe
    ElasticBeanstalk.instance.client.describe_application_versions(
      application_name: settings['name'],
      version_labels: [version]
    )
  end

  def version
    `git rev-parse HEAD`
  end
end
