module Ebx
  module Settings
    class LocalSettings < Base

      def initialize
        init_config
        @config = global_config['environments'][Ebx.env]['regions']
      end

      def write_config
        create_dir('.ebextentions')
        create_dir('eb')
        a = to_yaml

        File.open(Ebx.config_path, 'w') {|f| f.write(a)}
      end
    end
  end
end
