module Ebx
  module Settings
    class RemoteSettings < LocalSettings
      def initialize
        Settings.regions.each do |region|
          Ebx.set_region(region)

          descriptions = [
            AwsApplication.new.describe,
            AwsApplicationVersion.new.describe,
            AwsEnvironment.new.config,
            AwsConfigTemplate.new.describe
          ]
          global_config['environments'][Ebx.env]['regions'][region] = 
            descriptions.reduce({}) {|h, d| h.deep_merge(d) }.stringify_keys!
        end

        @config = global_config['environments'][Ebx.env]['regions']
      end
    end
  end
end
