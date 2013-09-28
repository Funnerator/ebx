module Ebx
  class NotificationService < AwsService

    def create
      @sns = sns.topics.create(Settings.get(:sns_name))
    end

    def subscribe(listener)
      create.subscribe(listener)
    end
  end
end
