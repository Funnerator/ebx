module Ebx
  class NotificationService < AwsService

    def create
      @sns = sns.topics.create(Settings.get(:sns_name))
    end

    def subscribe(listener)
      create
      if !@sns.subscriptions.find {|s| s.arn == listener.arn }
        @sns.subscribe(listener)
      end
    end
  end
end
