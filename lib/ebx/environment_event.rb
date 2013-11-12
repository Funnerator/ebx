module Ebx
  class EnvironmentEvent < AwsService
    include PrettyPrint

    attr_accessor :severity, :event_date, :message

    def self.fetch(env, from_time)
      Ebx.set_region(env.region)
      aws_events = AWS.elastic_beanstalk.client.describe_events({
        environment_id: env.id,
        start_time: from_time.utc.iso8601
      })[:events]
      aws_events.map {|e| self.new(e.merge(region: env.region)) }
    end

    def initialize(params)
      super
      self.severity = params[:severity]
      self.event_date = params[:event_date]
      self.message = params[:message]
    end

    def to_s
      "#{region} - #{colorize(severity)} #{event_date} #{message}"
    end
  end
end
