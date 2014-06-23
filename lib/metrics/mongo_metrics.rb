require 'active_support/core_ext/hash/indifferent_access'
require 'logger'
require 'json'
require 'uuidtools'
require 'redis'

def MongoMetrics(env_or_model, attributes = nil)
  if env_or_model.is_a?(Hash) && env_or_model["mongometrics.session"]
    env_or_model["mongometrics.session"]
  else
    session = MongoMetrics::Session.new(env_or_model, attributes)
    env_or_model["mongometrics.session"] = session if env_or_model.is_a?(Hash)
    session
  end
end

module MongoMetrics

  module Config
    extend self
    @settings = {}

    @database = nil
    @connection = nil

    def option(name, options = {})
      define_method(name) do
        @settings.has_key?(name) ? @settings[name] : options[:default]
      end
      define_method("#{name}=") { |value| @settings[name] = value }
      define_method("#{name}?") { send(name) }
    end

    # default some options with defaults
    option :database_name, :default => "metrics"
    option :cookie_name, :default => "_utmarr"
    option :cookie_expiration, :default => 60*24*60*60
    option :user_collection_name, :default => "aarrr_users"
    option :event_collection_name, :default => "aarrr_events"
    option :suppress_errors, :default => false

    def connection
      @connection || Mongo::Connection.new
    end

    def connection=(connection)
      @connection = connection
    end

    def database
      @database || connection.db(database_name)
    end

    def database=(database)
      @database = database
    end

    def users
      database[user_collection_name]
    end

    def events
      database[event_collection_name]
    end

  end

end

module MongoMetrics

  class << self

    def configure
      config = MongoMetrics::Config
      block_given? ? yield(config) : config
    end
    alias :config :configure
  end

  MongoMetrics::Config.public_instance_methods(false).each do |name|
    (class << self; self; end).class_eval <<-EOT
      def #{name}(*args)
        configure.send("#{name}", *args)
      end
    EOT
  end

end

module MongoMetrics

  class Session
    attr_accessor :id
    attr_accessor :env

    def initialize(env_or_object = nil, attributes = nil)
      self.env = env_or_object
      self.id = parse_id(env_or_object) || BSON::ObjectId.new.to_s

      attributes ||= {}
      attributes['data.last_request_at'] = Time.now.utc
      
      if Metrics::config[:use_queue]
        Metrics::EventQueue.push({:type => :metric, :method => :init, :id => id, :attributes => attributes})
      else
        MongoMetrics.users.update({"_id" => id}, {"$set" => attributes}, :upsert => true)
      end
    rescue Exception => e
      if MongoMetrics.suppress_errors
        puts "Unable to log metrics: #{e.to_s}"
      else
        raise e
      end
    end

    def user(opts = {})
      MongoMetrics.users.find_one({'_id' => id}, opts)
    end

    def set_cookie(response)
      response.set_cookie(MongoMetrics::Config.cookie_name, {
        :value => self.id,
        :path => "/",
        :expires => Time.now+MongoMetrics::Config.cookie_expiration
      })
    end

    def track(event_name, options = {})
      options = options.with_indifferent_access
      
      data = {
        "aarrr_user_id" => self.id,
        "event_name" => event_name.to_s,
        "event_type" => options["event_type"].to_s,
        "data" => options["data"],
        "referral_code" => options["referral_code"],
        "user_agent" => options["user_agent"] || get_user_agent,
        "created_at" => options["created_at"] || Time.now.getutc
      }
      
      if Metrics::config[:use_queue]
        Metrics::EventQueue.push({:type => :metric, :method => :track, :data => data})
      else
        result = MongoMetrics.events.insert(data)
        result
      end

    rescue Exception => e
      if MongoMetrics.suppress_errors
        puts "Unable to log metrics: #{e.to_s}"
      else
        raise e
      end
    end

    def update(attributes, options = {})
      if Metrics::config[:use_queue]
        Metrics::EventQueue.push({:type => :metric, :method => :update, :id => id, :attributes => attributes, :options => options})
      else
        MongoMetrics.users.update({"_id" => id}, attributes, options)
      end
    end

    def update_if_not_set(check_field, attributes, options = {}, check_nil = false)
      if Metrics::config[:use_queue]
        Metrics::EventQueue.push({:type => :metric, :method => :update_if_not_set, :check_field => check_field, :check_nil => check_nil, :id => id, :attributes => attributes, :options => options})
      else
        if check_nil
          MongoMetrics.users.update({'_id' => id, '$or' => [{check_field => nil}, {check_field => {'$exists' => false}}]}, attributes, options)
        else
          MongoMetrics.users.update({'_id' => id, check_field => {'$exists' => false}}, attributes, options)
        end
      end
    end

    protected

    def parse_id(env_or_object)
      request = Rack::Request.new(env_or_object)
      request.cookies[MongoMetrics::Config.cookie_name]
    end

    def get_user_agent
      if env.present?
        env["HTTP_USER_AGENT"].to_s
      end
    end

  end
end