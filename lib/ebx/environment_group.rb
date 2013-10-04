module Ebx
  class EnvironmentGroup
    include PrettyPrint

    attr_reader :regions, :configs, :environments, :booting_environments
    attr_accessor :start_time

    def initialize(regions)
      @regions = regions
      @configs = regions.map {|r| AwsConfigTemplate.new(region: r) }
      @environments = regions.map do |r|
        running = AwsEnvironment.find_running(r)
        running.empty? ? AwsEnvironment.new(region: r) : running
      end.flatten
    end

    def boot
      puts "Booting environments"
      self.start_time = Time.now

      NotificationService.new({}).create
      configs.each {|c| c.create }
      @booting_environments = regions.map { |r| AwsEnvironment.boot(r) }

      cycle_through_booting_environments
      environments
    end

    def during_boot(environment)
      start_time = Time.now # TODO will miss some events
      puts environment.events(start_time)
    end

    def after_boot(environment)
      old_env = environments.find {|env| env.region == environment.region }
      if old_env && old_env.running?
        puts "Swapping CNAMES"
        old_env.swap_cname_with(environment)

        puts "stopping #{old_env.name} #{old_env.running?} #{old_env.status}"
        old_env.stop

        environments.delete(old_env)
        environments << environment
      end
    end

    def describe(verbose)
      if environments.empty?
        "No running environments found in: #{regions.join(', ')}"
      else
        environments.map {|e| e.to_s(verbose) }
      end
    end

    def stop
      environments.each {|e| e.stop }
    end

    private

    def cycle_through_booting_environments
      booting_environments.cycle do |env|
        sleep(1.0)
        puts 'booting 1'
        during_boot(env)
        puts 'booting'
        binding.pry if env.health == :green
        after_boot(booting_environments.delete(env)) if (env.running? && env.health == :green)
      end
    end
  end
end
