module Ebx
  class AwsS3 < AwsService

    def push_application_version
      unless app_bucket.exists?
        s3.buckets.create(Settings.get(:s3_bucket))
      end

      app_bucket.objects[Settings.get(:s3_key)].tap do |o|
        unless o.exists?
          puts 'Bundling and pushing project'
          # This seems preferable, unfortunately seems to create an archive
          # that aws config parsing has a problem w/
          #zip = `git ls-tree -r --name-only HEAD | zip - -q -@`
          `git ls-tree -r --name-only HEAD | zip #{Settings.get(:s3_key)}.zip -q -@`
          o.write(File.open(Settings.get(:s3_key)+'.zip'))
          File.delete(Settings.get(:s3_key)+".zip")
        end
      end
    end

    def app_bucket
      # TODO use create_storage_location
      s3.buckets[Settings.get(:s3_bucket)]
    end
  end
end
