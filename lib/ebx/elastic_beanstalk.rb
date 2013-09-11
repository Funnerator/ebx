require 'singleton'

module Ebx
  class ElasticBeanstalk
    include Singleton

    def initialize
      update_settings
    end

    def client
      @eb.client
    end

    def update_settings
      @eb = AWS::ElasticBeanstalk.new
    end
  end
end
