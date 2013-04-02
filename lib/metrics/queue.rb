module Metrics
  
  module EventQueue
    
    class << self
      
      def start_worker

        (Metrics::config[:queue_workers] || 1).times do |i|
          consumer = Thread.new do
            while true
              event = Metrics::queue.pop
              
              unless Thread.current[:mongo_connection]
                Thread.current[:mongo_connection] = Mongo::Connection.new Metrics::mongo_host, Metrics::mongo_port, {:w => 0}
                Metrics::logger.info "Queue worker #{i} connected to MongoDB" if Metrics::logger
              end

              unless Thread.current[:realtime_connection]
                Thread.current[:realtime_connection] = Redis.new :host => Metrics::realtime_host, :port => Metrics::realtime_port
                Metrics::logger.info "Queue worker #{i} connected to Redis" if Metrics::logger
              end

              begin
                if event[:type] == :realtime
                  Thread.current[:realtime_connection].set event[:event_key], event[:event_json]
                  Thread.current[:realtime_connection].lpush event[:event_queue], event[:event_uuid]
                  Thread.current[:realtime_connection].expire event[:event_key], event[:event_expire]
                elsif event[:type] == :metric

                  if event[:method] == :init
                    Thread.current[:mongo_connection].db(MongoMetrics::Config.database_name)[MongoMetrics::Config.user_collection_name].update({"_id" => event[:id]}, {"$set" => event[:attributes] || {}}, :upsert => true)
                  elsif event[:method] == :track
                    Thread.current[:mongo_connection].db(MongoMetrics::Config.database_name)[MongoMetrics::Config.event_collection_name].insert(event[:data])
                  elsif event[:method] == :update
                    Thread.current[:mongo_connection].db(MongoMetrics::Config.database_name)[MongoMetrics::Config.user_collection_name].update({"_id" => event[:id]}, event[:attributes], event[:options])
                  elsif event[:method] == :update_if_not_set
                    if event[:check_nil]
                      Thread.current[:mongo_connection].db(MongoMetrics::Config.database_name)[MongoMetrics::Config.user_collection_name].update({'_id' => event[:id], '$or' => [{event[:check_field] => nil}, {event[:check_field] => {'$exists' => false}}]}, event[:attributes], event[:options])
                    else
                      Thread.current[:mongo_connection].db(MongoMetrics::Config.database_name)[MongoMetrics::Config.user_collection_name].update({'_id' => event[:id], event[:check_field] => {'$exists' => false}}, event[:attributes], event[:options])
                    end
                  end
                end

                if Metrics::config[:log_queue_size] && rand <= (Metrics::config[:log_queue_size_sample] || 1.0)
                  Metrics::logger.info "Events Queue size: #{Metrics::queue.size}" if Metrics::logger
                end
                
              rescue => e
                Metrics::logger.error "Metrics EventQueue error: #{event}: #{e}" if Metrics::logger
              end

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