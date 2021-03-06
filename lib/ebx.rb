require 'aws'
require 'pry'
require 'rainbow'
require 'zip'

require 'ebx/version'
require 'ebx/pretty_print'

require 'ebx/aws_service'
require 'ebx/aws_application'
require 'ebx/aws_application_version'
require 'ebx/aws_config_template'
require 'ebx/aws_credential_config'
require 'ebx/environment_event'
require 'ebx/aws_environment'
require 'ebx/aws_s3'
require 'ebx/notification_service'
require 'ebx/route53'
require 'ebx/aws_remote'
require 'ebx/remote_group'
require 'ebx/task_group'

require 'ebx/settings'
require 'ebx/deploy_group'
require 'ebx/boot_configuration'
require 'ebx/repository'

require 'ebx/core_ext/hash/deep_merge'
require 'ebx/core_ext/hash/keys'
require 'ebx/core_ext/object/deep_dup'

require 'ebx/lib/file_op'

module Ebx
  extend self

  attr_accessor :config_path, :env, :regions

  DEFAULT_ENV = 'development'
  DEFAULT_REGION = 'us-east-1'

  def config_path
    @config_path || File.expand_path("eb/environment.yml", Dir.pwd)
  end

  def env
    @env || ENV['AWS_ENV'] || DEFAULT_ENV
  end

  def set_region(region)
    AWS.config(region: region) 
  end

  def region
    AWS.config.region
  end

  AwsCredentialConfig.set_credentials
end
