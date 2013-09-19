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

    def logs
      Settings.regions.map do |region|
        Ebx.set_region(region)

        Aws.elastic_beanstalk.client.describe_events(
          application_name: Settings.get(:name)
        ).events
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
      Settings.config.to_yaml
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
  end
end
