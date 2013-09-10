class DeployGroup
  attr_accessor :global_settings

  def initialize
    @global_settings = AwsEnvironmentConfig.read_config[ENV['AWS_ENV']]
  end

  def create
    global_settings['environments'].each do |env_settings|
      AWS.config(region: env_settings['region'] || Ebx::DEFAULT_REGION)
      ElasticBeanstalk.instance.update_settings

      env_settings = global_settings.merge(env_settings)

      app = AwsApplication.new(env_settings)
      app.create

      ver = AwsApplicationVersion.new(env_settings)
      ver.create

      env = AwsEnvironment.new(env_settings)
      env.create
    end
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
