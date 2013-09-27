module Ebx
  module Settings
    class Base
      attr_reader :config

      def global_config
       unless FileTest.file?(Ebx.config_path)
       end
       @global_config ||= Psych.load_file(Ebx.config_path)
      end

      def region
        AWS.config.region
      end

      def regions
        Ebx.regions || config.keys
      end

      def master_region
        regions.first
      end

      def get(attr)
        config[region][attr.to_s] || generated_names[attr.to_s]
      rescue NoMethodError
        raise "Region #{region} not defined in #{Ebx.config_path}"
      end

      def set(attr, value)
        config[region][attr.to_s] = value
      end

      def diff(other_settings)
        config[Ebx.region].deep_diff(other_settings.config[Ebx.region])
      end

      def aws_params(*ebx_names)
        #ebx_names.reduce({}) {|h, n| h[EBX_TO_AWS[n]] = get(n); h }
        ebx_names.reduce({}) do |h, name|
          curr = h
          aws_ns = EBX_TO_AWS[name][1..-2].each {|k| curr = curr[k] = curr.fetch(k, {})}
          curr[EBX_TO_AWS[name][-1]] = name == :options ? option_settings(get(name)) : get(name)
          h
        end
      end

      def aws_settings_to_ebx(namespace, settings)
        return if !settings

        def translate(translation, source)
          source.inject({}) do |h,(k,v)|
            if v.is_a?(Hash) && k != :option_settings
              h.merge!(translate(translation[k], v))
            elsif translation[k]
              h[translation[k]] = v
            end

          h
          end
        end

        from = {}.tap {|h| h[namespace] = settings}
        translate(AWS_TO_EBX, from)
      end

      def yaml_node(hash)
        doc = Psych::Visitors::YAMLTree.new
        doc << hash
        doc.tree.children[0].children[0]
      end

      def to_yaml
        root_mapping = Psych::Nodes::Mapping.new
        settings = global_config['environments'].values
        default_regions = global_survey(settings)

        # Default Options
        options = settings.map {|a| a['regions'].values.map {|b| b['options'] } }.flatten(1)
        default_options = global_survey(options)
        options_tree = yaml_node(default_options)
        options_tree.anchor = 'default_options'
        root_mapping.children << Psych::Nodes::Scalar.new('options')
        root_mapping.children << options_tree

        # Default Attrs
        attrs = settings.map {|a| a['regions'].values.map {|b| b.select {|k,v| k != 'options' } } }.flatten(1)
        default_attrs = global_survey(attrs)
        attrs_tree = yaml_node(default_attrs)
        attrs_tree.anchor = 'default_attrs'
        root_mapping.children << Psych::Nodes::Scalar.new('attrs')
        attrs_tree.children << Psych::Nodes::Scalar.new('options')
        attrs_tree.children << Psych::Nodes::Alias.new('default_options')
        root_mapping.children << attrs_tree

        envs = {}
        global_config['environments'].each do |env, shash|
          locals = default_regions.deep_diff(shash)
          envs[env] = locals
        end

        # Default Regions
        regions_tree = Psych::Nodes::Mapping.new('default_regions')
        default_regions['regions'].each do |region, rhash|
          diff = default_attrs.merge('options' => default_options).deep_diff(rhash)
          if diff['options']
            options_node = yaml_node(diff.delete 'options')
            options_node.children.unshift Psych::Nodes::Alias.new('default_options')
            options_node.children.unshift Psych::Nodes::Scalar.new('<<')

            region_tree = yaml_node(diff)
            region_tree.children.unshift Psych::Nodes::Scalar.new('options')
            region_tree.children << options_node
          else
            region_tree = yaml_node(diff)
          end

          region_tree.children.unshift Psych::Nodes::Alias.new('default_attrs')
          region_tree.children.unshift Psych::Nodes::Scalar.new('<<')

          regions_tree.children << Psych::Nodes::Scalar.new(region)
          regions_tree.children << region_tree
        end
        root_mapping.children << Psych::Nodes::Scalar.new('regions')
        root_mapping.children << regions_tree


        # Environments
        environments_tree = Psych::Nodes::Mapping.new

        envs.each do |env, shash|
          env_tree = Psych::Nodes::Mapping.new
          env_tree.children << Psych::Nodes::Scalar.new('regions')

          #:wregion_tree = Psych::Nodes::Mapping.new
          if shash.empty?
            env_tree.children << Psych::Nodes::Alias.new('default_regions')
          elsif shash['regions']
            regions_node = Psych::Nodes::Mapping.new

            shash['regions'].each do |region, hsh|
              if hsh['options']
                options_node = yaml_node(hsh.delete 'options')
                options_node.children.unshift Psych::Nodes::Alias.new('default_options')
                options_node.children.unshift Psych::Nodes::Scalar.new('<<')
              end

              rnode = yaml_node(hsh)

              if options_node
                rnode.children << Psych::Nodes::Scalar.new('options')
                rnode.children << options_node
              end

              rnode.children.unshift Psych::Nodes::Alias.new('default_attrs')
              rnode.children.unshift Psych::Nodes::Scalar.new('<<')

              regions_node.children << Psych::Nodes::Scalar.new(region)
              regions_node.children << rnode
            end

            regions_node.children.unshift Psych::Nodes::Alias.new('default_regions')
            regions_node.children.unshift Psych::Nodes::Scalar.new('<<')

            env_tree.children << regions_node
          end

          environments_tree.children << Psych::Nodes::Scalar.new(env)
          environments_tree.children << env_tree
        end

        root_mapping.children << Psych::Nodes::Scalar.new('environments')
        root_mapping.children << environments_tree

        stream = Psych::Nodes::Stream.new
        doc = Psych::Nodes::Document.new
        stream.children << doc
        doc.children << root_mapping

        stream.to_yaml
      end

      private

      def global_survey(hashes)
        return {} if hashes.find {|a| a == nil }
        survey = HashCounter.new
        hashes.each do |hash|
          hash.each do |k, v|
            survey[k] =  v
          end
        end
        survey.global(hashes.size)
      end

      def generated_names
        settings = config[Ebx.region]
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

      def application_version(short = false)
        `git rev-parse #{'--short' if short} HEAD`.chomp!
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

      def branch_name
        `git rev-parse --abbrev-ref HEAD`
      end

      def env_prefix
        @env_prefix ||= rand(36**7).to_s(36)
      end

      def env_name
        "#{env_prefix}-#{Ebx.env}-#{branch_name}".strip.gsub(/\s/, '-')[0..22]
      end

      def option_settings(options)
        (options || []).reduce([]) do |a, (namespace,values)|
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

      private

      def init_config
        create_dir('.ebextentions')
        create_dir('eb')

        unless FileTest.file?(Ebx.config_path)
          FileUtils.cp(File.expand_path('../../../generators/templates/environment.yml', __FILE__), Ebx.config_path)
        end
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
