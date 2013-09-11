require 'singleton'

class AwsS3
  include Singleton

  def initialize
    update_settings
  end

  def client
    @s3.client
  end

  def update_settings
    @s3 = AWS::S3.new
  end

  def create_application_bucket
    application_bucket_name.tap do |n|
      unless @s3.buckets[n].exists?
        @s3.buckets.create(n)
      end
    end
  end

  def application_bucket_name
    "#{ENV['AWS_ENV']}-app-versions-#{AWS.config.region}"
  end

  def application_version_name(version)
    "git-#{version}"
  end

  def push_application_version(version)
    @s3.buckets[application_bucket_name].objects[application_version_name(version)].tap do |o|
      unless o.exists?
        zip = `git ls-tree -r --name-only HEAD | zip - -@`
        o.write(zip)
      end
    end

    application_version_name(version)
  end
end
