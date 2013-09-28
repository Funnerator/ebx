require 'ebx/application_group'
require 'ebx/environment_group'

module Ebx
  class DeployGroup

    def deploy
      ApplicationGroup.new(regions).push
      EnvironmentGroup.new(regions).boot
    end

    def describe(verbose = false)
      EnvironmentGroup.new(regions).describe(verbose)
    end

    def regions
      Settings.regions
    end

    def logs(follow = false)
      logs = "/var/log/eb* /var/log/cfn*"
      # /var/app/support/logs/* 
      regions.each do |region|
        if follow
          remote_execute("tail -f -n 0 #{logs}", true)
        else
          remote_execute("tail #{logs}")
        end
      end
    end

    def console
      app_location = '/var/app/current'
      Ebx.set_region(Ebx.master_region)
      remote_execute("cd #{app_location} && rails console", true)
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
      regions.each do |region|
        AwsEnvironment.new(region).stop
      end
    end

    def delete_application
      regions.each do |region|
        AwsApplication.new.delete
      end
    end

    def ec2_instance_ids
      Ebx.set_region(Settings.master_region)

      AwsEnvironment.new.ec2_instance_ids
    end

    def remote_shell
      ec2_id = ec2_instance_ids.first
      dns_name = AWS.ec2.instances[ec2_id].dns_name
      puts "ssh ec2-user@#{dns_name}\n"

      system "ssh ec2-user@#{dns_name}"
    end

    def remote_execute(cmd, subprocess = false)
      ec2_id = AwsEnvironment.new.ec2_instance_ids.first
      if !ec2_id
        puts "No active ec2 instances found for #{Settings.get(:environment_name)}"
        return
      end
      dns_name = AWS.ec2.instances[ec2_id].dns_name
      if subprocess
        system "ssh ec2-user@#{dns_name} #{cmd}"
      else
        `ssh ec2-user@#{dns_name} #{cmd}`
      end
    end
  end
end
