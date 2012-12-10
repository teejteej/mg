require 'metrics/version'
require 'metrics/mongo_metrics'
require 'metrics/queue'
require 'metrics/railtie' if defined?(Rails)

module Metrics
  
  class << self

    attr_accessor :mongo_host
    attr_accessor :mongo_port

    attr_accessor :realtime_host
    attr_accessor :realtime_port
    
    attr_writer :config
    attr_writer :realtime_config
    attr_writer :realtime_connection
    attr_writer :survey_config
    attr_writer :survey_cache
    attr_writer :queue
    
    def queue
      @queue
    end
    
    # For metrics
    def config
      @config || {}
    end
    
    # For fnordmetrics
    def realtime_config
      @realtime_config || {}
    end

    def realtime_configured?
      !realtime_config.empty?
    end
    
    def realtime_connection
      @realtime_connection || {}
    end
    
    # For Survey
    def survey_config
      @survey_config ||= {}
    end
    
    def survey_cache
      @survey_cache ||= {}
    end
    
    attr_accessor :logger
    
    def init(host, port, db, config = {})
      begin
        setup_logger
        self.mongo_host = host
        self.mongo_port = port
        self.config = config

        MongoMetrics.connection = Mongo::Connection.new host, port
        MongoMetrics::Config.cookie_expiration = 3600*24*999
        MongoMetrics::Config.database_name = db

        if self.config[:use_queue] && !self.queue
          self.queue = Queue.new
          EventQueue.start_worker
        end

        logger.info "Metrics initialized: #{host}:#{port}@#{db} [#{config}]" if self.config[:log_delays] && logger
      rescue => e
        if self.config[:exception_on_init_fail] && (!defined?(Rails) || (defined?(Rails) && Rails.env.production?))
          raise e
        else
          logger.warn "Track metrics not enabled (no MongoDB available)." if logger
        end
      end
    end
    
    def init_realtime(host, port, config = {})
      begin
        setup_logger
        self.realtime_host = host
        self.realtime_port = port
        self.realtime_config = {:event_prefix => 'fnordmetric'}.merge(config)
        self.realtime_connection = Redis.new :host => host, :port => port

        if self.realtime_config[:use_queue] && !self.queue
          self.queue = Queue.new
          EventQueue.start_worker
        end

        logger.info "Realtime Metrics initialized: #{host}:#{port} [#{realtime_config}]" if self.realtime_config[:log_delays] && logger
      rescue => e
        if self.realtime_config[:exception_on_init_fail] && (!defined?(Rails) || (defined?(Rails) && Rails.env.production?))
          raise e
        else
          logger.warn "track_realtime metrics not enabled (no Redis available)" if logger
        end
      end
    end
   
    def init_survey(type, config = {})
      begin
        self.survey_config[type] = {:cache_server => '127.0.0.1:11211', :votes_needed => 200, :event_name => "#{type}_score_1", :event_type => "#{type}_score", :cache_cohort => proc{"#{type}_score"}, :once_per_user => true}.merge(config)
        self.survey_cache[type] = Dalli::Client.new config[:cache_server]

        logger.info "#{type} Survey initialized: #{config}" if self.config[:log_delays] && logger
      rescue => e
        if self.config[:exception_on_init_fail] && (!defined?(Rails) || (defined?(Rails) && Rails.env.production?))
          raise e
        else
          logger.warn "#{type} not enabled (no Memcached available)" if logger
        end
      end
    end
  
private

    def setup_logger
      unless self.logger
        self.logger = defined?(Rails) ? Logger.new(Rails.root.join('log/metrics.log')) : Logger.new(STDOUT)
        self.logger.formatter = proc do |severity, datetime, progname, msg|
          datetime && defined?(datetime.iso8601) ? "#{datetime.iso8601} [#{severity}] #{msg}\n" : "#{datetime} [#{severity}] #{msg}\n"
        end
      end
    end

  end

end