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
      if old_env
        if old_env.running?
          puts "Swapping CNAMES"
          old_env.swap_cname_with(environment) { old_env.stop }
        end
        environments.delete(old_env)
      end
      environments << environment
    end

    def describe(verbose)
      environments.map {|e| e.to_s(verbose) }
    end

    def stop
      environments.each {|e| e.stop }
    end

    def restart
      environments.each {|e| e.restart }
    end

    private

    def cycle_through_booting_environments
      booting_environments.cycle do |env|
        sleep(1.0)
        during_boot(env)
        after_boot(booting_environments.delete(env)) if (env.running? && env.health == :green)
      end
    end
  end
end
