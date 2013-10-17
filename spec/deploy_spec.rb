require 'spec_helper'
require 'pry'

module Ebx
  describe DeployGroup do

    it 'passes', :vcr do
      VCR.use_cassette('describe') do
        DeployGroup.new.describe
      end
    end
  end
end
