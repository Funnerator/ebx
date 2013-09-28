module Ebx
  class AwsEnvironment < AwsService
    attr_accessor :id

    def self.boot(region)
      cur_env = AwsEnvironment.new(region: region)
      return cur_env if cur_env.current?

      new_env = AwsEnvironment.new(region: region)
      new_env.boot
      new_env.subscribe(NotificationService.new({}))
      new_env
    end

    def boot
      response = elastic_beanstalk.client.create_environment(
        Settings.aws_params(:name, :version, :environment_name, :template_name)
      )
      @id = response[:environment_id]
    end

    def id
      @id ||= describe[:environment_id]
    end

    def stop
      if running?
        puts "Stopping #{describe[:environment_name]} - #{describe[:environment_id]}"
        elastic_beanstalk.client.terminate_environment({
          environment_id: describe[:environment_id]
        })
      end
    end

    def swap_cname_with(other_env)
      elastic_beanstalk.client.swap_environment_cnam_es(
        source_environment_id: self.id,
        destination_environment_id: other_env.id
      )
    end

    def current?
      describe && describe[:version] == settings.get(:version)
    end

    def running?
      status[:env_status] == 'Ready'
    end

    def describe
      @description ||= begin
        if @id
          aws_desc = elastic_beanstalk.client.describe_environments({
            environment_ids: [id]
          })[:environments].first
        else
          environments = elastic_beanstalk.client.describe_environments(
            Settings.aws_params(:name)
          )[:environments]
          aws_desc = environments.find {|e| e['status'] == 'Ready' }
        end

        Settings.aws_settings_to_ebx(:environment, aws_desc)
      end
    end

    CONFIG_ATTRS = [:environment_name, :solution_stack, :environment_id, :cname, :endpoint_url]
    def config
      describe.select {|k, _| CONFIG_ATTRS.include? k }      
    end

    STATUS_ATTRS = [:env_status, :env_health, :endpoint_url]
    def status
      @description = nil
      if describe
        describe.select {|k, _| STATUS_ATTRS.include? k }      
      else
        {env_status: 'not running', env_health: 'off', endpoint_url: 'none'}
      end
    end

    def to_s(verbose = false)
      str = "#{Ebx.region} | #{Settings.get(:environment_name)} | #{colorize(status[:env_status])} | #{colorize(status[:env_health])} | #{status[:endpoint_url]}\n"

      if verbose
        str << "Events in the last hour: \n"

        events.each do |evt|
          str << "#{colorize(evt[:severity])} #{evt[:event_date]} #{evt[:message]}\n"
        end
      end

      str
    end

    def events(from_time = Time.now - 60*60*24)
      elastic_beanstalk.client.describe_events({
        environment_id: self.id,
        start_time: from_time.iso8601
      })[:events]
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
        str.color(:white)
      end
    end

    def subscribe(notification_service)
      puts "subscribing to notification service"
      @queue ||= sqs.queues.create(Settings.get(:sqs_name))
      notification_service.subscribe(@queue)
    end

    def describe_resources
      elastic_beanstalk.client.describe_environment_resources({
        :environment_name => Settings.get(:environment_name)
      })[:environment_resources]
    end

    def ec2_instance_ids
      describe_resources[:instances].collect{|i| i[:id]}
    end

  end
end
