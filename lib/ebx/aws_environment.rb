module Ebx
  class AwsEnvironment < AwsService
    include PrettyPrint

    attr_accessor :id

    def self.boot(region)
      cur_env = self.find_running(region)
      return cur_env if cur_env && cur_env.current?

      new_env = AwsEnvironment.new(region: region)
      new_env.boot
      new_env.subscribe(NotificationService.new({}))
      new_env
    end

    def self.master
      self.new(region: Settings.master_region)
    end

    def self.find_running(region)
      Ebx.set_region(region)
      environments = AWS.elastic_beanstalk.client.describe_environments(
        Settings.aws_params(:name)
      )[:environments]
      env = environments.find {|e| e[:status] != 'Terminated' }

      if env
        desc = Settings.aws_settings_to_ebx(:environment, aws_desc)
        self.new(region: region, id: desc[:environment_id])
      end
    end

    def initialize(params)
      super
      @id = params[:id]
    end

    def name
      describe[:environment_name]
    end

    def boot
      response = elastic_beanstalk.client.create_environment(
        Settings.aws_params(:name, :version, :environment_name, :template_name)
      )
      @id = response[:environment_id]
    end

    def stop
      if running?
        puts "Stopping #{name} - #{describe[:environment_id]}"
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
      describe && describe[:version] == Settings.get(:version)
    end

    def running?
      status[:env_status] == 'Ready'
    end

    def describe
      @description ||= begin
        aws_desc = elastic_beanstalk.client.describe_environments({
          environment_ids: [id]
        })[:environments].first

        Settings.aws_settings_to_ebx(:environment, aws_desc)
      end
    end

    CONFIG_ATTRS = [:environment_name, :solution_stack, :environment_id, :cname, :endpoint_url]
    def config
      describe.select {|k, _| CONFIG_ATTRS.include? k }      
    end

    STATUS_ATTRS = [:env_status, :env_health, :endpoint_url, :cname]
    def status
      @description = nil
      if describe
        describe.select {|k, _| STATUS_ATTRS.include? k }      
      else
        {env_status: 'not running', env_health: 'off', endpoint_url: 'none'}
      end
    end

    def to_s(verbose = false)
      str = "#{region} | #{name} | #{colorize(status[:env_status])} | #{colorize(status[:env_health])} | #{status[:cname]}\n"

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

    def subscribe(notification_service)
      puts "subscribing to notification service"
      @queue ||= sqs.queues.create(Settings.get(:sqs_name))
      notification_service.subscribe(@queue)
    end

    def describe_resources
      elastic_beanstalk.client.describe_environment_resources({
        :environment_name => name
      })[:environment_resources]
    end

    def ec2_instance_ids
      describe_resources[:instances].collect{|i| i[:id]}
    end

  end
end
