module Metrics
  
  module EventQueue
    
    class << self
      
      def start_worker

        (Metrics::config[:queue_workers] || 1).times do |i|
          consumer = Thread.new do
            Thread.current[:mg_thread_id] ||= (i + 1)
            # TODO for batching to work, same user_id should be assigned to same thread first!
            # Thread.current[:mg_current_batch] ||= []
            # Thread.current[:mg_last_batch_flush] = Time.now.utc
            
            while true
              batch_event = Metrics::queue(Thread.current[:mg_thread_id]).pop
              event = batch_event
              # Thread.current[:mg_current_batch] << batch_event
              
              begin
                if true || Thread.current[:mg_current_batch].size > 50 || (Time.now.utc - Thread.current[:mg_last_batch_flush]) > 5
                  # Metrics::logger.info "Flushing batch of size #{Thread.current[:mg_current_batch].size}. Events Queue size: #{Metrics::queue(Thread.current[:mg_thread_id]).size}" if Metrics::logger

                  if !Thread.current[:mg_client]
                    Thread.current[:mg_client] = JSONClient.new
                  end
                
                  # payload_batch = []
                  #
                  # Thread.current[:mg_current_batch].each do |event|
                    if event[:type] == :realtime
                      # Thread.current[:mg_realtime_connection].set event[:event_key], event[:event_json]
                      # Thread.current[:mg_realtime_connection].lpush event[:event_queue], event[:event_uuid]
                      # Thread.current[:mg_realtime_connection].expire event[:event_key], event[:event_expire]
                    elsif event[:type] == :metric
                      if event[:method] == :track
                        payload = {
                          "user_client": "browser",
                          "action": "event",
                          "name": event[:data]["event_name"],
                          "user_id": event[:data]["aarrr_user_id"],
                          "timestamp": event[:data]["created_at"].iso8601(3),

                          "event_id": SecureRandom.uuid,
                          "share_code": nil,
                          "referred_by_user_id": nil,

                          "properties": event[:data]["props"],

                          "context": {
                            "ip": event[:data]["ip"],
                            "user_agent": event[:data]["user_agent"],
                            "http_referer": event[:data]["referrer"],
                            "page_url": event[:data]["url"]
                          }
                        }
                      elsif event[:method] == :update || event[:method] == :update_if_not_set
                        payload = {
                          "user_client": "browser",
                          "action": "set",
                          "user_id": event[:id],
                          "timestamp": event[:options]["timestamp"].iso8601(3),

                          "share_code": nil,
                          "referred_by_user_id": nil,

                          "properties": event[:attributes],

                          "context": {
                            "ip": event[:options]["ip"],
                            "user_agent": event[:options]["user_agent"],
                            "http_referer": event[:options]["referrer"],
                            "page_url": event[:options]["url"]
                          }
                        }
                      elsif event[:method] == :identify
                        if event[:id] != event[:current_user]&.id&.to_s
                          payload = {
                            "user_client": "browser",
                            "action": "identify",
                            "previous_user_id": event[:id],
                            "user_id": event[:current_user]&.id&.to_s,
                            "timestamp": event[:options]["timestamp"].iso8601(3),

                            "share_code": nil,
                            "referred_by_user_id": nil,

                            "context": {
                              "ip": event[:options]["ip"],
                              "user_agent": event[:options]["user_agent"],
                              "http_referer": event[:options]["referrer"],
                              "page_url": event[:options]["url"]
                            }
                          }
                        else
                          payload = nil
                        end
                      end
                    end

                  #   if payload.present?
                  #     payload_batch << payload
                  #   end
                  # end
                  
                  if payload
                    if Metrics::config[:metrics_webhook_url].present? || ENV["METRICS_WEBHOOK_URL"].present?
                      Thread.current[:mg_client].post(Metrics::config[:metrics_webhook_url] || ENV["METRICS_WEBHOOK_URL"], payload)
                    else                      
                      # Metrics::logger.info "Sending payload size #{payload_batch.size}:\n#{payload_batch}" if Metrics::logger
                      Metrics::logger.info "Sending payload:\n#{payload}" if Metrics::logger
                    end
                  end
                  
                  # Thread.current[:mg_current_batch] = []
                  # Thread.current[:mg_last_batch_flush] = Time.now.utc
                end
              rescue => e
                Metrics::logger.error "Metrics EventQueue error: #{event}: #{e}" if Metrics::logger
              end

            end
          end
        end
        
      end
      
      def push(event, queue_id = nil)
        queue_id ||= (1 + rand * (Metrics::config[:queue_workers] || 1)).to_i
        
        Metrics::queue(queue_id) << event
      end
      
    end
    
  end
  
end