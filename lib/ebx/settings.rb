module Ebx
  module Settings
    extend self

    def config
      @config ||= begin
        yaml = Psych.load_file(Ebx.config_path)
        env_hsh = yaml['environments'][Ebx.env]
        regions = env_hsh['regions']

        regions.each do |region_name, region_hsh|
          base = env_hsh.clone
          base.delete('regions')
          user_defined = base.deep_merge(region_hsh || {})

          regions[region_name] = generated_names(user_defined).merge(user_defined)
        end

        regions
      end
    end

    def region
      AWS.config.region
    end

    def regions
      config.keys
    end

    def master_region
      regions.first
    end

    def get(attr)
      config[region][attr.to_s]
    rescue NoMethodError
      raise "Region #{region} not defined in #{config_path}"
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

      File.open(Ebx.config_path, 'w') {|f| f.write(Ebx.config.to_yaml)}
    end

    private

    def generated_names(settings)
      {
        'version' => application_version,
        'version_description' => version_description,
        's3_bucket' => application_bucket_name(settings),
        's3_key' => application_version_name,
        'sns_name' => notification_service_name,
        'sqs_name' => queue_service_name,
        'template_name' => template_name(settings),
        'environment_name' => env_name
      }
    end

    def application_version
      `git rev-parse HEAD`.chomp!
    end

    def application_bucket_name(settings)
      "#{Ebx.env}-app-versions-#{AWS.config.region}-#{settings['app_id']}"
    end

    def application_version_name
      "git-#{application_version}"
    end

    def notification_service_name
      "#{Ebx.env}-sns"
    end

    def queue_service_name
      "#{Ebx.env}-sqs"
    end

    def version_description
      `git log --pretty=format:'%s - %an' -1`.chomp!
    end

    def template_name(settings)
      "#{settings['name']}-#{Ebx.env}-template"
    end

    def env_name
      "#{Ebx.env}-#{`git rev-parse --abbrev-ref HEAD`}".strip.gsub(/\s/, '-')[0..23]
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
