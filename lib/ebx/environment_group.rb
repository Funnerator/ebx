module Ebx
  class EnvironmentGroup
    attr_reader :regions, :configs, :environments, :booting_environments

    def initialize(regions)
      @regions = regions
      @configs = regions.map {|r| AwsConfigTemplate.new(region: r) }
      @environments = regions.map {|r| AwsEnvironment.new(region: r) }
    end

    def boot
      puts "Booting environments"
      NotificationService.new({}).create
      configs.each {|c| c.create }
      @booting_environments = regions.map { |r| AwsEnvironment.boot(r) }

      booting_environments.cycle do |env|
        sleep(1.0)
        puts 'Booting...'
        after_boot(booting_environments.delete(env)) if env.running?
      end
    end

    def after_boot(environment)
      old_env = environments.find {|env| env.region == environment.region }
      if old_env && old_env.running?
        old_env.swap_cname_with(environment)
        old_env.stop

        environments.delete(old_env)
        environments << environment
      end
    end

    def describe(verbose)
      environments.map {|e| e.to_s(verbose) }
    end
  end
end
