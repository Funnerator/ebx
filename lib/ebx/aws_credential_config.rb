require 'yaml'

module Ebx
  class AwsCredentialConfig
    class << self
      # Use same credential file as eb
      def set_credentials
        secrets = {}
        File.open(File.expand_path('.elasticbeanstalk/aws_credential_file', Dir.home), 'r') do |f|
          secrets = f.readlines.reduce({}) do |h, line|
            k, v = *line.split("=")
            h[k] = v.strip
            h
          end
        end

        # if creds not in .elasticbeanstalk, check .ec2
        if secrets['AWSAccessKeyId'].nil? then
          File.open(File.expand_path('.ec2/access.keys', Dir.home), 'r') do |f|
            secrets = f.readlines.reduce({}) do |h, line|
              k, v = *line.split("=")
              h[k] = v.strip
              h
            end
          end
        end

        AWS.config({
          access_key_id: secrets['AWSAccessKeyId'],
          secret_access_key: secrets['AWSSecretKey'],
          dynamo_db: { api_version: '2012-08-10' }
        })
      end
    end
  end
end
