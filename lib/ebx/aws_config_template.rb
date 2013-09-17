module Ebx
  class AwsConfigTemplate
    attr_accessor :settings

    def initialize(settings)
      @settings = settings
    end

    #TODO move
    def option_settings
      (settings['options'] || []).reduce([]) do |a, (namespace,values)|
        values.each do |name,value|
          a << {
            namespace: namespace,
            option_name: name,
            value: value
          }
        end

        a
      end
    end

    def create
      begin
        app = AWS.elastic_beanstalk.client.describe_applications(
          application_names: [settings['name']]
        ).data[:applications].first

        template = if !app[:configuration_templates].include?(name)
          AWS.elastic_beanstalk.client.create_configuration_template(
            application_name: settings['name'],
            template_name: name,
            solution_stack_name: settings['solution_stack'],
            option_settings: option_settings
          )
        else
          AWS.elastic_beanstalk.client.update_configuration_template(
            application_name: settings['name'],
            template_name: name,
            option_settings: option_settings
          )
        end
      rescue Exception
        raise $! # TODO
      end
    end

    def describe
      AWS.elastic_beanstalk.client.describe_configuration_options(
        application_name: settings['name'],
        template_name: name
      )
    end

    def name
      "#{settings['name']}-#{ENV['AWS_ENV']}-template"
    end

  end
end
