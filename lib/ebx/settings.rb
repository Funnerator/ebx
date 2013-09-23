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
      yaml = Psych.load_file(Ebx.config_path)
      yaml['environments'].each do |env, env_hsh|
        regions = env_hsh['regions']

        regions.each do |region_name, region_hsh|
          base = env_hsh.clone
          base.delete('regions')
          user_defined = base.deep_merge(region_hsh || {})

          regions[region_name] = generated_names(user_defined).merge(user_defined)
        end
      end

      yaml
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
      if attr == :options
        option_settings(config[region]['options'])
      else
        config[region][attr.to_s]
      end
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

      #to_yaml = extract_globals
      to_ast
     
      #File.open(Ebx.config_path, 'w') {|f| f.write(config.to_yaml)}
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

    private

    def to_ast
      settings = top_config.deep_dup
      env_settings = settings['environments'][Ebx.env]['regions'] = config.deep_dup

      global_survey(settings['environments'].values)

    end

    def global_survey(hashes)
      survey = HashCounter.new
      hashes.each do |hash|
        hash.each do |k, v|
          survey[k] =  v
        end
      end
      binding.pry
    end

    def extract_globals
      to_yaml = config.deep_dup

      globals = to_yaml['base'] = to_yaml[master_region].deep_dup

      to_yaml.each do |region, rvalues|
        # Remove non-matched options in globals
        globals.each do |namespace, vals|
          vals.each do |name, val|
            v2 = rvalues[namespace] != nil ? rvalues[namespace][name] : nil

            if !val_eql?(val, v2)
              if globals[namespace].size == 1
                globals.delete(namespace)
              else 
                globals[namespace].delete(name)
              end
            end
          end
        end
      end

      # Remove globals from regions
      to_yaml.each do |region, rvalues|
        globals.each do |namespace, vals|
          vals.each do |name, val|
            v2 = rvalues[namespace] != nil ? rvalues[namespace][name] : nil

            if val_eql?(val, v2)
              if rvalues[namespace].size == 1
                rvalues.delete(namespace)
              else
                rvalues[namespace].delete(name)
              end
            end
          end
        end
      end

      to_yaml
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
  def initialize
    @hash = {}
    @global = {}
  end

  def []=(key, val)
    @hash[key] ||= {}

    if val.is_a? Hash
      @hash[key]['hsh'] ||= [HashCounter.new, 0]
      val.each do |k, v|
        @hash[key]['hsh'][0][k] = v
        @hash[key]['hsh'][1] += 1
      end
    else
      found = false
      @hash[key].each do |v, count|
        if val_eql?(v, val)
          found = true
          @hash[key][val] += 1
        end
      end

      @hash[key][val] = 1 if !found
    end
  end

  def global(counter)
    @hash.each do |k, values|
      count = 0
      values.each do |v, c|
        count += v == 'hsh' ? c[1] : c
      end

      @global[k] = get_global(k, values) if count >= counter
    end

    @global
  end

  def get_global(k, values)
    max, val = 0, nil
    values.each do |value, count|
      if value == 'hsh'
        hashCounter, c = *count
       if (max = [c, max].max) == c
         val = hashCounter.global(0)
       end
      else
        val = value if (max = [count,max].max) == count
      end
    end

    val
  end

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

  def inspect
    @hash.inspect
  end
end
