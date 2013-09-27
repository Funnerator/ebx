module Ebx
  class AwsEnvironment
    attr_accessor :queue, :id

    def self.boot(params = nil)
      response = AWS.elastic_beanstalk.client.create_environment(
        params || Settings.aws_params(:name, :version, :environment_name, :template_name)
      )

      Ebx::AwsEnvironment.new(id: response[:environment_id])
    end

    def initialize(attrs)
      @id = attrs[:id]
    end

    def id
      @id ||= describe[:environment_id]
    end

    def start
      if current? && !running?
        # boot
      end

      if !current?
        puts "Booting up environment #{Settings.get(:environment_name)}..."
        new_env = AwsEnvironment.boot
        loop do
          puts 'booting...'
          sleep(3.0)
          break if new_env.running?(true)
        end

        if running?
          puts 'Swapping CNAMES'
          swap_cname_with(new_env)
          stop
        end
      end

      @queue =  AWS.sqs.queues.create(Settings.get(:sqs_name))

    rescue Exception
      raise $! # TODO
    end

    def stop
      if running?
        puts "Stopping #{describe[:environment_name]} - #{describe[:environment_id]}"
        AWS.elastic_beanstalk.client.terminate_environment({
          environment_id: describe[:environment_id]
        })
      end

    rescue Exception
      raise $! # TODO
    end

    def swap_cname_with(other_env)
      Aws.elastic_beanstalk.client.swap_environment_cnam_es(
        source_environment_id: self.id,
        destination_environment_id: other_env.id
      )
    end

    def current?
      describe? && describe[:version] == settings.get(:version)
    end

    def running?(force_check = false)
      describe(force_check) && describe[:env_status] == 'Ready'
    end

    def describe(force_check = false)
      @description = nil if force_check
      @description ||= begin
        if @id
          aws_desc = AWS.elastic_beanstalk.client.describe_environments({
            environment_ids: [id]
          })[:environments].first
        else
          environments = AWS.elastic_beanstalk.client.describe_environments(
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
      describe.select {|k, _| STATUS_ATTRS.include? k }      
    end

    def to_s(verbose = false)
      st = exists? ? status : {:env_status => 'not running', :env_health => 'off', :endpoint_url => 'none'}

      str = "#{Ebx.region} | #{Settings.get(:environment_name)} | #{colorize(st[:env_status])} | #{colorize(st[:env_health])} | #{st[:endpoint_url]}\n"

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
        str.color(:white)
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
