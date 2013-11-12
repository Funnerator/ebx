require 'ebx/application_group'
require 'ebx/environment_group'
require 'ebx/database_group'

module Ebx
  class DeployGroup

    def deploy
      Repository.check_pushed!
      ApplicationGroup.new(regions).push
      EnvironmentGroup.new(regions).boot
      Repository.tag_deployment
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
