class AwsEnvironment
  attr_accessor :settings

  def initialize(settings)
    @settings = settings
  end

  def create
    begin
      if describe[:environments].empty?
        ElasticBeanstalk.instance.client.create_environment(
          application_name: settings['name'],
          version_label: settings['version'],
          environment_name: settings['env_name'],
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

  def stop
    begin
      if !describe[:environments].empty?
        environments = ElasticBeanstalk.instance.client.describe_environments({
          environment_names: [settings['env_name']]
        })[:environments]

        environments.each do |env|
          puts "Stopping #{env[:environment_name]} - #{env[:environment_id]}"
          ElasticBeanstalk.instance.client.terminate_environment({
            environment_id: env[:environment_id]
          })
        end

      end
    rescue Exception
      raise $! # TODO
    end
  end

  def describe
    ElasticBeanstalk.instance.client.describe_environments({
      environment_names: [settings['env_name']]
    })
  end
end
