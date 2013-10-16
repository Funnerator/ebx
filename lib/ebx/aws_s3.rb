module Ebx
  class AwsS3 < AwsService
    def initialize(attrs)
      super(attrs)

      unless app_bucket.exists?
        s3.buckets.create(Settings.get(:s3_bucket))
      end
    end

    def push_application_version
      app_bucket.objects[Settings.get(:s3_key)].tap do |o|
        unless o.exists?
          puts 'Bundling and pushing project'
          generate_tmp_eb_files
          write_to_object(o)
          delete_tmp_eb_files
        end
      end
    end

    def app_bucket
      s3.buckets[Settings.get(:s3_bucket)]
    end

    def boot_configuration
      @boot_configuration ||= BootConfiguration.new(region: region)
    end

    private

    def generate_tmp_eb_files
      boot_configuration.write_ebextensions
    end

    def tmp_eb_files
      boot_configuration.files
    end

    def delete_tmp_eb_files
      boot_configuration.delete_ebextensions
    end

    # This seems preferable, unfortunately seems to create an archive
    # that aws config parsing has a problem w/
    #zip = `git ls-tree -r --name-only HEAD | zip - -q -@`
    def write_to_object(object)
      bundle_name = '.bundle.tmp'
      write_bundle(bundle_name)
      object.write(File.open(bundle_name))
      File.delete(bundle_name)
    end

    def file_list
      `git ls-tree -r --name-only HEAD`.split
    end

    def write_bundle(name)
      Zip::File.open(name, Zip::File::CREATE) do |zipfile|
        (tmp_eb_files + file_list).each {|f| zipfile.add(f,f) }
      end
    end
  end
end
