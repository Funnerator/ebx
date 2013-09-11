module Ebx
  class AwsEnvironment
    attr_accessor :settings, :queue

    def initialize(settings={})
      @settings = settings
    end

    def create
      begin
        if describe.empty?
          ElasticBeanstalk.instance.client.create_environment(
            application_name: settings['name'],
            version_label: settings['version'],
            environment_name: env_name,
            solution_stack_name: settings['solution_stack'],
            #option_settings: [{
            #  namespace: 'aws:autoscaling:launchconfiguration',
            #  option_name: 'IamInstanceProfile',
            #  option_value: 'ElasticBeanstalkProfile'
            #}]
          )

          sqs = AWS::SQS.new
          @queue =  sqs.queues.create(sqs_name)

        end
      rescue Exception
        raise $! # TODO
      end
    end

    def stop
      begin
        if !describe.empty?
          describe.each do |env|
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
        environment_names: [env_name],
        include_deleted: false
      })[:environments]
    end

    def sqs_name
      "#{ENV['AWS_ENV']}-sns"
    end

    def env_name
      "#{ENV['AWS_ENV']}-#{`git rev-parse --abbrev-ref HEAD`}".strip.gsub(/\s/, '-')[0..23]
    end

    def subscribe(notification_service)
      notification_service.subscribe(queue)
    end
  end
end
