require 'active_support/core_ext/hash/indifferent_access'
require 'logger'
require 'json'
require 'jsonclient'

def TrackMetrics(env_or_model, attributes = nil)
  if env_or_model.is_a?(Hash) && env_or_model["trackmetrics.session"]
    env_or_model["trackmetrics.session"]
  else
    session = TrackMetrics::Session.new(env_or_model, attributes)
    env_or_model["trackmetrics.session"] = session if env_or_model.is_a?(Hash)
    session
  end
end

module TrackMetrics

  module Config
    extend self
    @settings = {}

    def option(name, options = {})
      define_method(name) do
        @settings.has_key?(name) ? @settings[name] : options[:default]
      end
      define_method("#{name}=") { |value| @settings[name] = value }
      define_method("#{name}?") { send(name) }
    end

    # default some options with defaults
    option :cookie_name, :default => "_utmarr"
    option :cookie_expiration, :default => 365*24*60*60
  end

end

module TrackMetrics

  class Session
    attr_accessor :id
    attr_accessor :env

    def initialize(env_or_object = nil, attributes = nil)
      self.env = env_or_object
      existing_id = parse_id(env_or_object)
      self.id = existing_id || SecureRandom.uuid

      attributes ||= {}
      attributes['data.last_request_at'] = Time.now.utc
    rescue Exception => e
      if defined?(Rails) && Rails.env.development?
        raise e
      else
        puts "Unable to log metrics: #{e.to_s}"
      end
    end

    def user(opts = {})
    end

    def set_cookie(response)
      response.set_cookie(TrackMetrics::Config.cookie_name, {
        :value => self.id,
        :path => "/",
        :expires => Time.now+TrackMetrics::Config.cookie_expiration
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
        "created_at" => options["created_at"] || Time.now.getutc,
        "props" => options["props"],
        "ip" => options["ip"],
        "url" => options["url"],
        "referrer" => options["referrer"]
      }
      
      Metrics::EventQueue.push({:type => :metric, :method => :track, :data => data}, consistent_index_from_id)
    rescue Exception => e
      if defined?(Rails) && Rails.env.development?
        raise e
      else
        puts "Unable to log metrics: #{e.to_s}"
      end
    end

    def identify_user(current_user, options, response)
      if current_user && current_user.id.present?
        Metrics::EventQueue.push({:type => :metric, :method => :identify, :id => id, :current_user => current_user, :options => options}, consistent_index_from_id)
      
        self.id = current_user.id.to_s
        set_cookie(response)
      end
    end

    def update(attributes, options = {})
      Metrics::EventQueue.push({:type => :metric, :method => :update, :id => id, :attributes => attributes, :options => options}, consistent_index_from_id)
    end

    def update_if_not_set(check_field, attributes, options = {}, check_nil = false)
      Metrics::EventQueue.push({:type => :metric, :method => :update_if_not_set, :check_field => check_field, :check_nil => check_nil, :id => id, :attributes => attributes, :options => options}, consistent_index_from_id)
    end

    protected

    def consistent_index_from_id
      (Digest::MD5.hexdigest(self.id).to_i(16) % (Metrics::config[:queue_workers] || 1))+1
    end
    
    def parse_id(env_or_object)
      request = Rack::Request.new(env_or_object)
      request.cookies[TrackMetrics::Config.cookie_name]
    end

    def get_user_agent
      if env.present?
        env["HTTP_USER_AGENT"].to_s
      end
    end

  end
end