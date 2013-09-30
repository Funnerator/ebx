module Ebx
  class ApplicationGroup
    attr_reader :s3_buckets, :applications, :versions

    def initialize(regions)
      @s3_buckets = regions.map {|r| AwsS3.new(region: r) }
      @applications = regions.map {|r| AwsApplication.new(region: r) }
      @versions = regions.map {|r| AwsApplicationVersion.new(region: r) }
    end

    def push
      s3_buckets.each {|b| b.push_application_version }
      applications.each {|a| a.create }
      versions.each {|v| v.create }
    end

    def delete
      applications.each {|a| a.delete }
    end
  end
end
