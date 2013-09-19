module Ebx
  class AwsEnvironment
    attr_accessor :queue

    def create
      begin
        if describe.empty?
          puts 'Creating environment'
          AWS.elastic_beanstalk.client.create_environment(
            application_name: Settings.get(:name),
            version_label: Settings.get(:version),
            environment_name: Settings.get(:environment_name),
            template_name: Settings.get(:template_name)
          )
        end

        @queue =  AWS.sqs.queues.create(Settings.get(:sqs_name))
      rescue Exception
        raise $! # TODO
      end
    end

    def stop
      begin
        if !describe.empty?
          describe.each do |env|
            puts "Stopping #{env[:environment_name]} - #{env[:environment_id]}"
            AWS.elastic_beanstalk.client.terminate_environment({
              environment_id: env[:environment_id]
            })
          end
        end
      rescue Exception
        raise $! # TODO
      end
    end

    def describe
      AWS.elastic_beanstalk.client.describe_environments({
        environment_names: [Settings.get(:environment_name)],
        include_deleted: false
      })[:environments]
    end

    def to_s(verbose = false)
      desc = describe.first

      str = "#{Ebx.region} | #{Settings.get(:environment_name)} | #{colorize(desc[:status])} | #{colorize(desc[:health])} | #{desc[:endpoint_url]}\n"

      if verbose
        str << "Events in the last hour: \n"

        events = AWS.elastic_beanstalk.client.describe_events({
          environment_name: Settings.get(:environment_name),
          start_time: (Time.now - 60*60*24).iso8601
        })[:events].each do |evt|
          str << "#{colorize(evt[:severity])} #{evt[:event_date]} #{evt[:message]}\n"
        end
      end

      str
    end

    def colorize(str)
      case str
      when 'Red', 'ERROR', 'FATAL'
        str.color(:red)
      when 'WARN'
        str.color(:yellow)
      when 'Ready', 'Green', 'INFO'
        str.color(:green)
      else
        str
      end
    end

    def subscribe(notification_service)
      puts "subscribing to notification service"
      notification_service.subscribe(queue)
    end

    def describe_resources
      AWS.elastic_beanstalk.client.describe_environment_resources({
        :environment_name => Settings.get(:environment_name)
      })[:environment_resources]
    end

    def ec2_instance_ids
      describe_resources[:instances].collect{|i| i[:id]}
    end

  end
end
