require 'ebx/application_group'
require 'ebx/environment_group'

module Ebx
  class DeployGroup

    def deploy
      ApplicationGroup.new(regions).push
      environments = EnvironmentGroup.new(regions).boot
      Route53.new.update_cnames(environments)
    end

    def describe(verbose = false)
      EnvironmentGroup.new(regions).describe(verbose)
    end

    def logs
      regions.map do |region|
        AwsRemote.new(region: region).logs
      end
    end

    def stop
      EnvironmentGroup.new(regions).stop
    end

    def restart
      EnvironmentGroup.new(regions).restart
    end

    def delete_application
      ApplicationGroup.new(regions).delete
    end

    def regions
      Settings.regions
    end
  end
end
