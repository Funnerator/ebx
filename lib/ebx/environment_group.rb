module Ebx
  class EnvironmentGroup
    include PrettyPrint

    attr_reader :regions, :configs, :environments, :booting_environments

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
      configs.each {|c| c.create }
      @booting_environments = regions.map { |r| AwsEnvironment.boot(r) }

      cycle_through_booting_environments

      DatabaseGroup.new(environments).boot
      Route53.new.update_cnames(environments)

      environments
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
      @start_time = Time.now
      booting_environments.cycle do |env|
        sleep(1.0)
        during_boot(env)
        after_boot(booting_environments.delete(env)) if (env.running? && env.health == :green)
      end
    end

    def during_boot(environment)
      puts environment.events(@start_time)
      @start_time = Time.now # TODO will miss some events
    end

    def after_boot(environment)
      old_env = environments.find {|env| env.region == environment.region }
      if old_env
        swap_cnames(old_env, environment) if old_env.running?
        environments.delete(old_env)
      end
      environments << environment
    end

    def swap_cnames(from, to)
      puts "Swapping CNAMES"
      from.swap_cname_with(to) { from.stop }
    end
  end
end
