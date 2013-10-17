require 'rubygems'
require 'bundler/setup'
require 'vcr'

require 'ebx'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
end

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
  c.hook_into :webmock # or :fakeweb
end

def stub_config
  AWS::Core::Configuration.new({
    :access_key_id => 'ACCESS_KEY_ID',
    :secret_access_key => 'SECRET_ACCESS_KEY'
  })
end
