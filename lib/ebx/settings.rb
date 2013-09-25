module Ebx
  module Settings
    extend self

    EBX_TO_AWS = {
      name: [:application, :application_name],
      description: [:application, :description],

      version: [:application_version, :version_label],
      version_description: [:application_version, :description],
      s3_bucket: [:application_version, :source_bundle, :s3_bucket],
      s3_key: [:application_version, :source_bundle, :s3_key],

      environment_name: [:environment, :environment_name],
      solution_stack: [:environment, :solution_stack_name],
      environment_id: [:environment, :environment_id],
      cname: [:environment, :cname],
      endpoint_url: [:environment, :endpoint_url],
      env_status: [:environment, :status],
      env_health: [:environment, :health],

      template_name: [:environment_template, :template_name],
      options: [:environment_template, :option_settings]
    }

    # Constructs reverse mapping with form
    # {
    #   application: {
    #     application_name: :name
    #   }
    # }
    AWS_TO_EBX = begin
      EBX_TO_AWS.inject({}) do |h, (ebx_n, aws_ns)|
        curr = h
        aws_ns[0..-2].each {|n| curr = curr[n] = curr.fetch(n, {}) }
        curr[aws_ns[-1]] = ebx_n
        h
      end
    end

    def config
      @config ||= top_config['environments'][Ebx.env]['regions']
    end

    def top_config
      Psych.load_file(Ebx.config_path)
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
      config[region][attr.to_s] || generated_names(config[region])[attr.to_s]
    rescue NoMethodError
      raise "Region #{region} not defined in #{Ebx.config_path}"
    end

    def set(attr, value)
      config[region][attr.to_s] = value
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

    def remote
      descriptions = [
        AwsApplication.new.describe,
        AwsApplicationVersion.new.describe,
        AwsEnvironment.new.config,
        AwsConfigTemplate.new.describe
      ]
      descriptions.reduce({}) {|h, d| h.deep_merge(d) }.stringify_keys!
    end

    def remote_diff
      diff = {
        add: [],
        modify: [],
        delete: []
      }

      local = config[Ebx.region].clone
      remote.each do |k, v|
        if local[k]
          if local[k] != v
            diff[:modify] << { "#{k}" => [v, local[k]] }
          end
          local.delete(k)
        else
          diff[:delete] << { "#{k}" => v }
        end
      end

      local.each do |k, v|
        diff[:add] << { "#{k}" => v }
      end

      diff
    end

    def aws_params(*ebx_names)
      #ebx_names.reduce({}) {|h, n| h[EBX_TO_AWS[n]] = get(n); h }
      ebx_names.reduce({}) do |h, name|
        curr = h
        aws_ns = EBX_TO_AWS[name][1..-2].each {|k| curr = curr[k] = curr.fetch(k, {})}
        curr[EBX_TO_AWS[name][-1]] = get(name)
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
      settings = top_config['environments'].values
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
      top_config['environments'].each do |env, shash|
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

    def delete_global_dups(parent, children)
      children.each do |key, hsh|
        parent.each do |k, v|
          children[key].delete(k) if hsh[k] == v
        end
      end
    end

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
  end
end

class HashCounter
  def initialize(hsh= nil)
    @hash = {}
    @global = {}

    add_hash(hsh) if hsh
  end

  def add_hash(hsh)
    hsh.each do |k, v|
      self[k] = v
    end
  end

  def []=(key, val)
    store = @hash[key] ||= []

    item = store.find { |v, c| val_eql?(v, val) || (v.is_a?(HashCounter) && val.is_a?(Hash)) }
    if val.is_a?(Hash)
      if !item
        store << item = [HashCounter.new(val), 0]
      else
        item[0].add_hash(val)
      end
    elsif !item
      store << item = [val, 0]
    end

    item[1] += 1
  end

  def global(counter)
    @hash.each do |k, vals|
      count = vals.inject(0) {|s, (_,c)| s += c }
      if count == counter
        val, c = *vals.max_by(&:last)
        @global[k] = val.is_a?(HashCounter) ? val.global_hash : val
      end
    end

    @global
  end

  def inspect
    @hash.inspect
  end

  def global_hash
    max = 0
    @hash.each do |k, vals|
      max = [max, vals.max_by(&:last)[1]].max
    end

    @hash.each do |k, vals|
      val, _ = *vals.find {|_, c| c >= (max / 2.0).ceil }
      if val
        @global[k] = val.is_a?(HashCounter) ? val.global_hash : val
      end
    end

    @global
  end

  private

  def val_eql?(val1, val2)
    return false if !(val1 === val2)
    case val1
    when Array
      return false if val1.size != val2.size
      val1.zip(val2).inject(true) {|b, (v1, v2)| b && val_eql?(v1,v2) }
    when Hash
      val1.inject(true) { |b, (k,v)| b && val_eql?(v, val2[k]) }
    else
      val1 == val2
    end
  end
end
