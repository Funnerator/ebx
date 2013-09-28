module Ebx
  class AwsS3 < AwsService

    def push_application_version
      unless app_bucket.exists?
        s3.buckets.create(Settings.get(:s3_bucket))
      end

      app_bucket.objects[Settings.get(:s3_key)].tap do |o|
        unless o.exists?
          puts 'Bundling and pushing project'
          zip = `git ls-tree -r --name-only HEAD | zip - -q -@`
          o.write(zip)
        end
      end
    end

    def app_bucket
      # TODO use create_storage_location
      s3.buckets[Settings.get(:s3_bucket)]
    end
  end
end
