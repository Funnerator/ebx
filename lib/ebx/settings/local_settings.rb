module Ebx
  module Settings
    class LocalSettings < Base

      def initialize
        @config = global_config['environments'][Ebx.env]['regions']
      end

      def init_config
        create_dir('.ebextentions')
        create_dir('eb')

        unless FileTest.file?(Ebx.config_path)
          FileUtils.cp(File.expand_path('../../generators/templates/environment.yml', __FILE__), Ebx.config_path)
        end
      end

      def write_config
        create_dir('.ebextentions')
        create_dir('eb')
        a = to_yaml

        File.open(Ebx.config_path, 'w') {|f| f.write(a)}
      end

      private

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
