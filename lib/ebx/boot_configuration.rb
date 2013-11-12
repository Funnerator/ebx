module Ebx
  class BootConfiguration < AwsService
    def write_ebextensions
      FileOp.create_dir(eb_dir)
      return if !Settings[:environment_configuration]
      Settings[:environment_configuration].each_with_index do |config, i|
        File.open("#{eb_dir}/run%03d.config" % (i + 1), 'w') do |f|
          f.write(config.to_yaml)
        end
      end
    end

    def delete_ebextensions
      FileUtils.rm_r(eb_dir)
    end

    def files
      Dir["#{eb_dir}/**/*"].reject {|fn| File.directory?(fn) }
    end

    def eb_dir
      '.ebextensions'
    end
  end
end
