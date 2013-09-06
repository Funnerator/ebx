class AwsEnvironment
  attr_accessor :settings

  def initialize(settings)
    @settings = settings.merge(AwsEnvironmentConfig.read_config[ENV['AWS_ENV']])
  end

  def create
    begin
      if describe[:environments].empty?
        ElasticBeanstalk.instance.client.create_environment(
          application_name: settings[:app_name],
          version_label: version,
          environment_name: name,
          solution_stack_name: settings['solution_stack'],
          #option_settings: [{
          #  namespace: 'aws:autoscaling:launchconfiguration',
          #  option_name: 'IamInstanceProfile',
          #  option_value: 'ElasticBeanstalkProfile'
          #}]
        )
      end
    rescue Exception
      raise $! # TODO
    end
  end

  def version
    `git rev-parse HEAD`
  end

  def name
    "#{ENV['AWS_ENV']}-#{`git rev-parse --abbrev-ref HEAD`}".strip.gsub(/\s/, '-')[0..23]
  end

  def describe
    ElasticBeanstalk.instance.client.describe_environments({
      environment_names: [name]
    })
  end
end
