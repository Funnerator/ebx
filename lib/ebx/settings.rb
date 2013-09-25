require 'ebx/settings/local_settings'
require 'ebx/settings/remote_settings'
require 'ebx/settings/hash_counter'

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

    # TODO not a very good pattern..
    def method_missing(method, *args, &block)
      @setting ||= LocalSettings.new
      @setting.send(method, *args, &block)
    end
  end
end
