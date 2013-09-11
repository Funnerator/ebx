class DeployGroup
  attr_accessor :global_settings

  def initialize
    @global_settings = AwsEnvironmentConfig.read_config[ENV['AWS_ENV']]
  end

  def create
    global_settings.merge!(
      'version' => version,
      'env_name' => env_name
    )

    global_settings['environments'].each do |env_settings|
      AWS.config(region: env_settings['region'] || Ebx::DEFAULT_REGION)

      ElasticBeanstalk.instance.update_settings
      AwsS3.instance.update_settings

      env_settings = global_settings.merge(env_settings)

      s3_bucket = AwsS3.instance.create_application_bucket
      s3_key = AwsS3.instance.push_application_version(version)

      env_settings.merge!({
        's3_bucket' => s3_bucket,
        's3_key' => s3_key
      })

      app = AwsApplication.new(env_settings)
      app.create

      ver = AwsApplicationVersion.new(env_settings)
      ver.create

      env = AwsEnvironment.new(env_settings)
      env.create
    end
  end

  def version
    `git rev-parse HEAD`.chomp!
  end

  def env_name
    "#{ENV['AWS_ENV']}-#{`git rev-parse --abbrev-ref HEAD`}".strip.gsub(/\s/, '-')[0..23]
  end

  def stop
    global_settings['environments'].each do |env_settings|
      AWS.config(region: env_settings['region'] || Ebx::DEFAULT_REGION)
      ElasticBeanstalk.instance.update_settings

      env_settings = global_settings.merge(env_settings)

      env = AwsEnvironment.new(env_settings)
      env.stop
    end
  end
end
