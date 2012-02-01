require 'metrics/version'
require 'metrics/railtie' if defined?(Rails)

module Metrics
  
  class << self
    # For aarrr
    attr_accessor :config
    
    # For fnordmetrics
    attr_accessor :realtime_config
    attr_accessor :realtime_connection

    # For NPS
    attr_accessor :nps_config
    attr_accessor :nps_cache
    
    def init(host, port, db, config = {})
      begin
        self.config = config

        AARRR.connection = Mongo::Connection.new host, port
        AARRR::Config.cookie_expiration = 3600*24*999
        AARRR::Config.database_name = db

        puts "Metrics initialized: #{host}:#{port}@#{db} [#{config}]" if self.config[:log_delays]

        # Patch AARRR
        patch = <<-PATCH
        module ::AARRR
          class Session
            def set_data(data)
              update({"data" => data})
            end
          end
        end
        PATCH

        eval patch
      rescue => e
        if !(defined?(Rails) && Rails.env.development?)
          raise e
        else
          puts "Warning: track metrics not enabled (no MongoDB available)."
        end
      end
    end
    
    def init_realtime(host, port, config = {})
      begin
        self.realtime_config = {:event_prefix => 'fnordmetric'}.merge(config)
        self.realtime_connection = Redis.new :host => host, :port => port

        puts "Realtime Metrics initialized: #{host}:#{port} [#{realtime_config}]" if self.realtime_config[:log_delays]
      rescue => e
        if !(defined?(Rails) && Rails.env.development?)
          raise e
        else
          puts "Warning: track_realtime metrics not enabled (no Redis available)"
        end
      end
    end
   
    def init_nps(config = {})
      begin
        self.nps_config = {:cache_server => '127.0.0.1:11211', :votes_needed => 200, :event_name => 'nps_score_1', :event_type => 'nps_score', :cache_cohort => proc{'nps_score'}, :once_per_user => true}.merge(config)
        self.nps_cache = Dalli::Client.new config[:cache_server]

        puts "NPS Survey initialized: #{config}" if self.config[:log_delays]
      rescue => e
        if !(defined?(Rails) && Rails.env.development?)
          raise e
        else
          puts "Warning: NPS not enabled (no Memcached available)"
        end
      end
    end
    
  end

end