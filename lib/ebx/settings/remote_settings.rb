module Ebx
  module Settings
    class RemoteSettings < Base
      def initialize
        init_config
        @config = global_config['environments'][Ebx.env]['regions']

        Settings.regions.each do |region|
          Ebx.set_region(region)

          descriptions = [
            AwsApplication.new.describe,
            AwsApplicationVersion.new.describe,
            AwsEnvironment.new.config,
            AwsConfigTemplate.new.describe
          ]

          global_config['environments'][Ebx.env]['regions'][region] = 
            generated_names.deep_diff(descriptions.reduce({}) {|h, d| h.deep_merge(d) }.stringify_keys!)
        end
      end
    end
  end
end
