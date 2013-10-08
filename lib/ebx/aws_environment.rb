module Ebx
  class AwsEnvironment < AwsService
    include PrettyPrint

    attr_accessor :id
    NON_ACTIVE_STATUSES = ['Terminating', 'Terminated']

    def self.boot(region)
      #cur_env = self.find_running(region)
      #return cur_env if cur_env && cur_env.current?

      new_env = AwsEnvironment.new(region: region)
      new_env.boot
      new_env.subscribe_to_db_queues
      new_env
    end

    def self.master
      self.find_running(Settings.master_region).first || self.new(region: Settings.master_region)
    end

    def self.find_running(region)
      Ebx.set_region(region)
      environments = AWS.elastic_beanstalk.client.describe_environments(
        Settings.aws_params(:name)
      )[:environments]
      envs = environments.select {|e| !['Terminated'].include?(e[:status]) }
      envs.map {|e| self.new(region: region, id: e[:environment_id]) }
    end

    # Find masters by cname pointed to from route53

    def initialize(params)
      super
      @id = params[:id]
    end

    def name
      config[:environment_name] || Settings.get(:name)
    end

    def cname
      status[:cname]
    end

    def boot
      response = elastic_beanstalk.client.create_environment(
        Settings.aws_params(:name, :version, :environment_name, :template_name)
      )
      @id = response[:environment_id]
    end

    def stop
      if running?
        puts "Stopping #{region} | #{name}"
        elastic_beanstalk.client.terminate_environment({
          environment_id: id
        })
      end
    end

    def restart
      elastic_beanstalk.client.restart_app_server(
        environment_id: id
      )
    end

    def swap_cname_with(other_env, &block)
      elastic_beanstalk.client.swap_environment_cnam_es(
        source_environment_id: self.id,
        destination_environment_id: other_env.id
      )
      if block
        while updating?
          sleep 2
        end
        yield
      end
    end

    def updating?
      status[:env_status] == 'Updating'
    end

    def current?
      config[:version] == Settings.get(:version)
    end

    def running?
      !NON_ACTIVE_STATUSES.include?(status[:env_status])
    end

    def health
      status[:env_health].downcase.to_sym
    end

    def describe
      if id
        aws_desc = elastic_beanstalk.client.describe_environments({
          environment_ids: [id]
        })[:environments].first

        @description ||= Settings.aws_settings_to_ebx(:environment, aws_desc)
      end
    end

    CONFIG_ATTRS = [:environment_name, :solution_stack, :environment_id, :cname, :endpoint_url]
    def config
      @config ||= (describe || {}).select {|k, _| CONFIG_ATTRS.include? k }      
    end

    STATUS_ATTRS = [:env_status, :env_health, :endpoint_url, :cname]
    def status
      @description = nil
      if describe
        describe.select {|k, _| STATUS_ATTRS.include? k }      
      else
        {env_status: 'Terminated', env_health: 'off', cname: 'none'}
      end
    end

    def to_s(verbose = false)
      msg = ["#{region} | #{name} | #{colorize(status[:env_status])} | #{colorize(status[:env_health])} | #{status[:cname]}"]

      if verbose
        msg << ["Events in the last hour:"]
        msg = msg + events
      end
      msg
    end

    def events(from_time = Time.now - 60*60*24)
      EnvironmentEvent.fetch(self, from_time)
    end

    def subscribe_to_db_queues
      puts "subscribing to notification service"
      NotificationService.new.tap do |ns|
        ns.attach_read_queue(sqs.queues.create(Settings.get(:read_sqs_name)))
        ns.attach_write_queue(sqs.queues.create(Settings.get(:write_sqs_name)))
      end
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
