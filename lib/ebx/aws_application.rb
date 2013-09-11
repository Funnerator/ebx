module Ebx
  class AwsApplication
    attr_accessor :settings

    def initialize(settings)
      @settings = settings
    end

    def create
      begin
        if describe[:applications].empty?
          ElasticBeanstalk.instance.client.create_application(
            application_name: settings['name'],
            description: settings['description']
          )
        end
      rescue Exception
        raise $! # TODO
      end
    end

    def describe
      ElasticBeanstalk.instance.client.describe_applications(
        application_names: [settings['name']]
      )
    end
  end
end
