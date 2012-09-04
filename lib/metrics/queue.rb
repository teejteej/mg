module Metrics
  
  module EventQueue
    
    class << self
      
      def start_worker

        consumer = Thread.new do
          while true
            event = Metrics::queue.pop

            begin
              if event[:type] == :realtime
                Metrics::realtime_connection.set event[:event_key], event[:event_json]
                Metrics::realtime_connection.lpush event[:event_queue], event[:event_uuid]
                Metrics::realtime_connection.expire event[:event_key], event[:event_expire]
              elsif event[:type] == :metric

                if event[:method] == :init
                  MongoMetrics.users.update({"_id" => event[:id]}, {"$set" => event[:attributes] || {}}, :upsert => true)
                elsif event[:method] == :track
                  MongoMetrics.events.insert(event[:data])
                elsif event[:method] == :update
                  MongoMetrics.users.update({"_id" => event[:id]}, event[:attributes], event[:options])
                elsif event[:method] == :update_if_not_set
                  if event[:check_nil]
                    MongoMetrics.users.update({'_id' => event[:id], '$or' => [{event[:check_field] => nil}, {event[:check_field] => {'$exists' => false}}]}, event[:attributes], event[:options])
                  else
                    MongoMetrics.users.update({'_id' => event[:id], event[:check_field] => {'$exists' => false}}, event[:attributes], event[:options])
                  end
                end
              end
            rescue => e
              Metrics::logger.error "Metrics EventQueue error: #{event}: #{e}" if Metrics::logger
            end

          end
        end
        
      end
      
      def push(event)
        Metrics::queue << event
      end
      
    end
    
  end
  
end