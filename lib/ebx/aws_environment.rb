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
            template_name: config_template_name
          )


        end
        @queue =  AWS.sqs.queues.create(sqs_name)
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

    def config_template_name
      "#{settings['name']}-#{ENV['AWS_ENV']}-template"
    end

    def subscribe(notification_service)
      notification_service.subscribe(queue)
    end

    def describe_resources
      ElasticBeanstalk.instance.client.describe_environment_resources({
        :environment_name => env_name
      })[:environment_resources]
    end

    def ec2_instance_ids
      describe_resources[:instances].collect{|i| i[:id]}
    end

  end
end
