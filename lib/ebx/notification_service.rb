module Ebx
  class NotificationService < AwsService

    def initialize(attrs)
      attrs.merge!(region: Settings.master_region)
      super(attrs)

      @write_sns = sns.topics.create(Settings.get(:write_sns_name))
      @read_sns = sns.topics.create(Settings.get(:read_sns_name))
    end

    def attach_read_queue(queue)
      subscribe(read_sns, queue)
    end

    def attach_write_queue(queue)
      subscribe(write_sns, queue)
    end

    private

    def subscribe(sns, queue)
      if !sns.subscriptions.find {|s| s.endpoint == queue.arn }
        sns.subscribe(queue)
      end
    end
  end
end
