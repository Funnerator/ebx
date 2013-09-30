module Ebx
  class EnvironmentGroup
    include PrettyPrint

    attr_reader :regions, :configs, :environments, :booting_environments

    def initialize(regions)
      @regions = regions
      @configs = regions.map {|r| AwsConfigTemplate.new(region: r) }
      @environments = regions.map {|r| AwsEnvironment.find_running(r) }.compact
    end

    def boot
      puts "Booting environments"
      start_time = Time.now
      NotificationService.new({}).create
      configs.each {|c| c.create }
      @booting_environments = regions.map { |r| AwsEnvironment.boot(r) }

      puts 'Booting...'
      booting_environments.cycle do |env|
        sleep(1.0)

        event_time = start_time
        start_time = Time.now
        env.events(event_time).each do |evt|
          puts "#{env.region} - #{colorize(evt[:severity])} #{evt[:event_date]} #{evt[:message]}"
        end

        after_boot(booting_environments.delete(env))  if env.running?
      end
    end

    def after_boot(environment)
      old_env = environments.find {|env| env.region == environment.region }
      if old_env && old_env.running?
        puts "Swapping CNAMES"
        old_env.swap_cname_with(environment)
        old_env.stop

        environments.delete(old_env)
        environments << environment
      end
    end

    def describe(verbose)
      environments.map {|e| e.to_s(verbose) }
    end

    def stop
      environments.each {|e| e.stop }
    end
  end
end
