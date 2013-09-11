require 'yaml'

module Ebx
  class AwsEnvironmentConfig

    class << self
      def config_path
        File.expand_path("eb/environment.yml", Dir.pwd)
      end

      def config_exists?
        FileTest.file?(config_path)
      end

      def read_config
        @config ||= YAML.load_file(config_path)
      end

      def init_config
        create_dir('.ebextentions')
        create_dir('eb')

        unless FileTest.file?(config_path)
          FileUtils.cp(File.expand_path('../../generators/templates/environment.yml', __FILE__), config_path)
        end

        read_config
      end

      def create_dir(name)
        dir = File.expand_path(name, Dir.pwd)

        raise "#{name} exists and is not a directory" if FileTest.file?(dir)
        unless FileTest.directory?(dir)
          Dir.mkdir(dir)
        end
      end
    end
  end
end
