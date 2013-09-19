module Ebx
  class DeployGroup

    def create
      Settings.regions.each do |region|
        Ebx.set_region(region)
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
      Settings.regions.each do |region|
        Ebx.set_region(region)

        say AwsEnvironment.new.to_s(verbose)
      end
    end

    def logs(follow = false)
      logs = "/var/log/eb* /var/app/support/logs/* /var/log/cfn*"
      Settings.regions.map do |region|
        Ebx.set_region(region)

        if follow
          remote_execute("tail -f #{logs}", true)
        else
          remote_execute("tail #{logs}")
        end
      end
    end

    def pull_config_settings
      Settings.regions.each do |region|
        Ebx.set_region(region)

        region_options = AwsConfigTemplate.new.pull_options
        Settings.set(:options, region_options)
      end

      puts "Writing remote config to #{Ebx.config_path}"
      Settings.write_config
    end

    def config
      Settings.regions.map do |region|
        {}.tap {|h| h[region] = Settings.config[region] }.to_yaml
      end
    end

    def stop
      Settings.regions.each do |region|
        Ebx.set_region(region)

        AwsEnvironment.new.stop
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

    def remote_execute(cmd, subproccess = false)
      ec2_id = AwsEnvironment.new.ec2_instance_ids.first
      dns_name = AWS.ec2.instances[ec2_id].dns_name
      if subprocess
        system "ssh ec2-user@#{dns_name} #{cmd}"
      else
        `ssh ec2-user@#{dns_name} #{cmd}`
      end
    end
  end
end
