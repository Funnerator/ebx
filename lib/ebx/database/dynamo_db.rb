module Ebx
  module Database
    class DynamoDb < AwsDatabase

      def boot
        subscribe_to_ns
      end

      def subscribe_to_ns
        puts "subscribing to notification service"
        ::Ebx::NotificationService.new.tap do |ns|
          ns.attach_read_queue(sqs.queues.create(::Ebx::Settings.get(:read_sqs_name)))
          ns.attach_write_queue(sqs.queues.create(::Ebx::Settings.get(:write_sqs_name)))
        end
      end
    end
  end
end
