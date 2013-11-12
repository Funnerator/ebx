module Ebx
  module Database
    class DynamoDb
      def boot
        subscribe_to_ns
      end

      def subscribe_to_db_queues
        puts "subscribing to notification service"
        NotificationService.new.tap do |ns|
          ns.attach_read_queue(sqs.queues.create(Settings.get(:read_sqs_name)))
          ns.attach_write_queue(sqs.queues.create(Settings.get(:write_sqs_name)))
        end
      end
    end
  end
end
