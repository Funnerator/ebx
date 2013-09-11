module Ebx
  class DeployGroup
    attr_accessor :global_settings

    def initialize
      @global_settings = AwsEnvironmentConfig.read_config[ENV['AWS_ENV']]
    end

    def environments
      global_settings['environments']
    end

    def create
      global_settings.merge!(
        'version' => version,
        'env_name' => env_name
      )

      environments.each do |env_settings|
        AWS.config(region: env_settings['region'] || Ebx::DEFAULT_REGION)

        ElasticBeanstalk.instance.update_settings
        AwsS3.instance.update_settings

        sqs = AWS::SQS.new
        queue =  sqs.queues.create(sqs_name)

        notification_service.subscribe(@queue)

        env_settings = global_settings.merge(env_settings)

        s3_bucket = AwsS3.instance.create_application_bucket
        s3_key = AwsS3.instance.push_application_version(version)

        env_settings.merge!({
          's3_bucket' => s3_bucket,
          's3_key' => s3_key
        })

        app = AwsApplication.new(env_settings)
        app.create

        ver = AwsApplicationVersion.new(env_settings)
        ver.create

        env = AwsEnvironment.new(env_settings)
        env.create
      end
    end

    def notification_service
      # Topic created for first environment
      @topic ||= begin
        old_region = AWS.config.region
        AWS.config(region: environments.first['region'] || Ebx::DEFAULT_REGION)
        sns = AWS::SNS.new
        sns.topics.create(sns_name)
      end
    ensure
      AWS.config(region: old_region)
    end

    def sns_name
      env_name
    end

    def sqs_name
      "#{env_name}-sns"
    end

    def version
      `git rev-parse HEAD`.chomp!
    end

    def version_description
      `git log --pretty=format:'%s - %an' -1`.chomp!
    end

    def env_name
      "#{ENV['AWS_ENV']}-#{`git rev-parse --abbrev-ref HEAD`}".strip.gsub(/\s/, '-')[0..23]
    end

    def stop
      global_settings['environments'].each do |env_settings|
        AWS.config(region: env_settings['region'] || Ebx::DEFAULT_REGION)
        ElasticBeanstalk.instance.update_settings

        env_settings = global_settings.merge(env_settings)

        env = AwsEnvironment.new(env_settings)
        env.stop
      end
    end
  end
end
