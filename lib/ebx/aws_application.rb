module Ebx
  class AwsApplication
    attr_accessor :settings

    def initialize(settings)
      @settings = settings
    end

    def create
      begin
        if !exists?
          ElasticBeanstalk.instance.client.create_application(
            application_name: settings['name'],
            description: settings['description']
          )
        end
      rescue Exception
        raise $! # TODO
      end
    end

    def exists?
      !!describe
    end

    def describe
      AWS.elastic_beanstalk.client.describe_applications(
        application_names: [settings['name']]
      ).data[:applications].first
    end
  end
end
