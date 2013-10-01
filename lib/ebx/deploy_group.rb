require 'ebx/application_group'
require 'ebx/environment_group'

module Ebx
  class DeployGroup

    def deploy
      Route53.new
      ApplicationGroup.new(regions).push
      EnvironmentGroup.new(regions).boot
    end

    def describe(verbose = false)
      EnvironmentGroup.new(regions).describe(verbose)
    end

    def regions
      Settings.regions
    end

    def logs
      regions.map do |region|
        AwsRemote.new(region: region).logs
      end
    end

    def pull_config_settings
      puts "Fetching remote settings for #{Ebx.env} environment"
      remote_settings = Settings::RemoteSettings.new
      puts "Writing remote config to #{Ebx.config_path}"
      remote_settings.write_config
    end

    def push_config_settings
      `git fetch`
      if !`git status -s #{Ebx.config_path}`.empty?
        puts "You have local changes to your ebx config that have not been pushed to \
your remote repository yet. To keep everyone in sync, please do so \
before pushing aws configuration changes"
      elsif !`git log HEAD..origin #{Ebx.config_path}`.empty?
        puts "Please pull the latest changes to the ebx config before \
pushing configuration changes"
      else
        regions.each do |region|
          Settings.push
        end
      end
    end

    def settings_diff
      s = []
      remote = Settings::RemoteSettings.new
      regions.each do |region|
        s << { "#{region}" => Settings.diff(remote).stringify_keys! }.to_yaml
      end

      s
    end

    def settings(where = 'local')
      case where
      when 'local'
        Settings.config.to_yaml
      when 'remote'
        Settings::RemoteSettings.new.config.to_yaml
      end
    end

    def stop
      EnvironmentGroup.new(regions).stop
    end

    def delete_application
      ApplicationGroup.new(regions).delete
    end
  end
end
