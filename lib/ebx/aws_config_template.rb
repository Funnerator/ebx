module Ebx
  class AwsConfigTemplate < AwsService

    def create
      begin
        app = elastic_beanstalk.client.describe_applications(
          application_names: [Settings.get(:name)]
        ).data[:applications].first

        template = if !app[:configuration_templates].include?(Settings.get(:template_name))
          puts "Creating configuration template"
          elastic_beanstalk.client.create_configuration_template(
            Settings.aws_params(:name, :template_name, :solution_stack, :options)
          )
        else
          puts "Updating configuration template"
          elastic_beanstalk.client.update_configuration_template(
            Settings.aws_params(:name, :template_name, :options)
          )
        end
      rescue Exception
        raise $! # TODO
      end
    end

    def describe
      @description ||= begin
        aws_desc = elastic_beanstalk.client.describe_configuration_settings(
          application_name: Settings.get(:name),
          template_name: Settings.get(:template_name),
        )[:configuration_settings].first

        option_hash = {}
        aws_desc[:option_settings].group_by {|h| h[:namespace] }.each do |namespace, h|
          h.each do |setting|
            option = options.find {|o| o[:namespace] == namespace && o[:name] == setting[:option_name] }

            # TODO overinclusive
            if !option || setting[:value] != option[:default_value]
              (option_hash[namespace] ||= {}).tap do |oh|
                oh.store(setting[:option_name], setting[:value])
              end
            end
          end
        end
        aws_desc[:option_settings] = option_hash

        Settings.aws_settings_to_ebx(:environment_template, aws_desc)
      end
    end

    def options
      @options ||= elastic_beanstalk.client.describe_configuration_options(
        application_name: Settings.get(:name),
        template_name: Settings.get(:template_name),
      )[:options]
    end

    def pull_options
      describe[:options]
    end
  end
end
