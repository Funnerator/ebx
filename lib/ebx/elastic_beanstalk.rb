require 'singleton'

class ElasticBeanstalk
  include Singleton

  def initialize
    @eb = AWS::ElasticBeanstalk.new
  end

  def client
    @eb.client
  end
end
