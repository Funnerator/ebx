module Ebx
  class RemoteGroup
    attr_accessor :regions

    def initialize(regions = Settings.regions)
      @regions = regions
    end

    def rake(cmd, options = {})
      regions.each do |r|
        AwsRemote.new(options.merge(region: r)).rake(cmd)
      end
    end
  end
end
