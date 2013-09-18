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

    def describe
      Settings.regions.each do |region|
        Ebx.set_region(region)

        env = AwsEnvironment.new
        env.describe.each do |env|
          say env.to_s
        end
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
      globals = nil
      all_options = Settings.regions.map do |region|
        Ebx.set_region(region)

        region_options = AwsConfigTemplate.new.pull_options
        if !globals
          globals = Marshal.load(Marshal.dump(region_options)) #TODO deep clone
        else
          globals = simple_global_compare(globals, region_options)
        end

        region_options
      end

      # clean up empty namespaces
      globals.delete_if {|k,v| v.empty? }

      all_options.map do |region_options|
        # remove global settings
      end

      #if global_settings['options'] || !globals.empty?
      #  if globals.empty?
      #    global_settings['options'] = globals
      #  else
      #    global_settings.delete('options')
      #  end
      #end

      all_options.each_with_index do |region_options, i|
        if !region_options.empty?
          regions[i]['options'] = region_options
        end
      end

      AwsEnvironmentConfig.write_config
    end

    #TODO Deep compare of hashes
    def simple_global_compare(hs1, hs2)
      new_global = hs1.clone

      hs1.keys.each do |namespace|
        if !hs2[namespace]
          new_global.delete(namespace) 
          next
        end

        hs1[namespace].each do |name,val|
          if !hs2[name] || hs2[name] != val
            new_global[namespace].delete(name)
          end
        end
      end

      new_global
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
