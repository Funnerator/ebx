require 'aws'
require 'pry'
require 'rainbow'

require 'ebx/version'
require 'ebx/aws_credential_config'
require 'ebx/aws_application'
require 'ebx/aws_application_version'
require 'ebx/aws_environment'
require 'ebx/settings'
require 'ebx/aws_config_template'
require 'ebx/aws_s3'
require 'ebx/deploy_group'
require 'ebx/version'

require 'ebx/core_ext/hash/deep_merge'
require 'ebx/core_ext/hash/deep_dup'

module Ebx
  extend self

  attr_accessor :config_path, :env

  DEFAULT_ENV = 'development'

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
end
