require 'singleton'

module Ebx
  class AwsS3

    def push_application_version
      unless app_bucket.exists?
        AWS.s3.buckets.create(Settings.get(:s3_bucket))
      end

      app_bucket.objects[Settings.get(:s3_key)].tap do |o|
        unless o.exists?
          zip = `git ls-tree -r --name-only HEAD | zip - -@`
          o.write(zip)
        end
      end
    end

    def app_bucket
      AWS.s3.buckets[Settings.get(:s3_bucket)]
    end
  end
end
