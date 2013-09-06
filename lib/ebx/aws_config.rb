require 'yaml'

class AwsCredentialConfig
  class << self
    # Use same credential file as eb
    def set_credentials
      File.open(File.expand_path('.elasticbeanstalk/aws_credential_file', Dir.home), 'r') do |f|
        secrets = f.readlines.reduce({}) do |h, line|
          k, v = *line.split("=")
          h[k] = v.strip
          h
        end

        AWS.config({
          access_key_id: secrets['AWSAccessKeyId'],
          secret_access_key: secrets['AWSSecretKey'],
        })
      end
    end
  end
end
