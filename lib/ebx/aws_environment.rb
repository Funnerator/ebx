module Ebx
  class AwsEnvironment
    attr_accessor :settings, :queue

    def initialize(settings={})
      @settings = settings
    end

    def create
      option_settings = []
      settings['option_settings'].each do |ns, v|
        v.each do |k,v|
          val = { namespace: ns }
          val['option_name'] = k
          val['value'] = v
          option_settings.push(val)
        end
      end unless settings['option_settings'].nil?

      begin
        if describe.empty?
          ElasticBeanstalk.instance.client.create_environment(
            application_name: settings['name'],
            version_label: settings['version'],
            environment_name: env_name,
            solution_stack_name: settings['solution_stack'],
            option_settings: option_settings
          )
        end
        sqs = AWS::SQS.new
        @queue =  sqs.queues.create(sqs_name)
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
