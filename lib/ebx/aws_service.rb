module Ebx
  class AwsService
    attr_accessor :region

    def initialize(params = {})
      @region = params[:region] || Settings.master_region
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
