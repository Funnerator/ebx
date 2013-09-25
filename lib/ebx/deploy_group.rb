module Ebx
  class DeployGroup

    def create
      each_region do |region|
        puts "Deploying to #{region}"

        puts "Pushing application to S3"
        s3 = AwsS3.new
        s3.push_application_version

        app = AwsApplication.new
        app.create

        ver = AwsApplicationVersion.new
        ver.create

        conf = AwsConfigTemplate.new
        conf.create

        env = AwsEnvironment.new
        env.create

        env.subscribe(notification_service)
      end
    end

    def notification_service
      @topic ||= begin
        old_region = Settings.region
        Ebx.set_region(Settings.master_region)
        AWS.sns.topics.create(Settings.get(:sns_name))
      end
    ensure
      Ebx.set_region(old_region)
    end

    def describe(verbose = false)
      each_region do |region|
        say AwsEnvironment.new.to_s(verbose)
      end
    end

    def logs(follow = false)
      logs = "/var/log/eb* /var/log/cfn*"
      # /var/app/support/logs/* 
      each_region do |region|

        if follow
          remote_execute("tail -f -n 0 #{logs}", true)
        else
          remote_execute("tail #{logs}")
        end
      end
    end

    # TODO Does not work yet
    def pull_config_settings
      each_region do |region|
        #region_options = AwsConfigTemplate.new.pull_options
        #Settings.set(:options, region_options)
      end

      puts "Writing remote config to #{Ebx.config_path}"
      Settings.write_config
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
        each_region do |region|
          Settings.push
        end
      end
    end

    def settings_diff
      s = []
      each_region do |region|
        s << { "#{region}" => Settings.remote_diff.stringify_keys! }.to_yaml
      end

      s
    end

    def settings(where = 'local')
      s = []
      each_region do |region|
        if where == 'local'
          s << { "#{region}" => Settings.config[region] }.to_yaml
        elsif where == 'remote'
          s << { "#{region}" => Settings.remote }.to_yaml
        end
      end

      s
    end

    def stop
      each_region do |region|
        AwsEnvironment.new.stop
      end
    end

    def delete_application
      each_region do |region|
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

    def each_region(regions = Settings.regions, &block)
      regions.each do |region|
        Ebx.set_region(region)
        yield region
      end
    end
  end
end
