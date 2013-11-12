module Ebx
  class AwsService
    attr_accessor :region

    def initialize(params = {})
      @environment = params[:environment]
      @region = AwsService.extract_region(params)
    end

    def self.extract_region(params)
      env = params[:env]
      (env && env.region) ||
        params[:region] ||
        Settings.master_region
    end

    SERVICES = [
      :elastic_beanstalk,
      :s3,
      :sqs,
      :sns,
      :ec2
    ]

    SERVICES.each do |service|
      define_method(service) do
        Ebx.set_region(region)
        AWS.send(service)
      end
    end
  end
end
