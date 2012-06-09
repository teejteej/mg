module MetricsHelper

  BOTS = /(bot|^$|spider|AACrawler|HttpClient|SWRLinkchecker|NING|Kimengi|InAGist|Extractor-Engine|AACrawler|SWRLinkchecker|W3C_Validator|wget|curl|Trend Micro|facebookexternalhit|URL Control|panopta|FlaxCrawler|YahooCacheSystem|xenu link|VB Project|ruby|rganalytics|MFE_expand|AppEngine-Google|DailyPerfect|lwp-request|Mail.RU|PageGetter|Harvester|unshort.me|UnwindFetchor|Mediapartners|MetaURI|JS-Kit|urlresolver|RockMeltEmbedService|LongURL|PostRank|ia_archiver|Summify|urllib|Baidu|Gigabot|Googlebot|libwww-perl|lwp-trivial|msnbot|pingdom|SiteUptime|Slurp|WordPress|ZIBB|ZyBorg)/i

  def log_metrics_delay(start, method)
    delay = (Time.now - start) * 1000

    if Metrics::config[:log_delays]
      Metrics::logger.info "#{method} metrics time: #{delay} ms" if Metrics::logger
    end
    
    if Metrics::config[:log_delays_as_realtime_event] && rand <= Metrics::config[:log_delays_realtime_sample]
      track_realtime Metrics::config[:log_delays_as_realtime_event], {:delay => delay}, :skip_log_delay => true
    end
  end

  def log_realtime_metrics_delay(start, method)
    delay = (Time.now - start) * 1000

    if Metrics::realtime_config[:log_delays]
      Metrics::logger.info "#{method} realtime metrics time: #{delay} ms" if Metrics::logger
    end

    if Metrics::realtime_config[:log_delays_as_realtime_event] && rand <= Metrics::realtime_config[:log_delays_realtime_sample]
      track_realtime Metrics::realtime_config[:log_delays_as_realtime_event], {:delay => delay}, :skip_log_delay => true
    end
  end

  def metrics_error(e, type = 'Track', skip_track_realtime = false)
    Metrics::logger.error "#{type} metric error: #{e}" if Metrics::logger

    if !skip_track_realtime && Metrics::config[:log_errors_as_realtime_event]
      track_realtime Metrics::config[:log_errors_as_realtime_event], {:type => type}, :skip_log_delay => true
    end    
  end
  
  def set_metrics_identity
    begin
      start = Time.now
      
      if !(request.user_agent =~ BOTS)
        if !cookies[MongoMetrics::Config.cookie_name]
          MongoMetrics(request.env).set_cookie(response)
          data = [
            {:key => :first_visit, :value => Time.now.utc, :overwrite => true}, 
            {:key => :share_code, :value => (("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a).sort_by{rand}[0,7].join, :overwrite => true},
            {:key => :first_visit_referrer, :value => request.env['HTTP_REFERER'], :overwrite => true}
          ]
          data << {:key => :first_visit_source, :value => params[:src], :overwrite => true} unless params[:src].blank?
          set_user_metric_data data
          
          track_metric :referral, :referrer, {:referral_code => request.params['vt'][0..10]}, request unless request.params['vt'].blank?
        end
      end

      log_metrics_delay start, "set_metrics_identity"
    rescue => e
      metrics_error e
    end
  end

  def track_extra_metrics
    begin
      if !(request.user_agent =~ BOTS)
        if !request.session[:visit_start].blank? && !request.session[:no_landing_bounce_tracked]
          if (Time.now-request.session[:visit_start]) > (Metrics::config[:no_bounce_seconds] || 10).seconds
            track_metric :acquisition, :no_landing_bounce, {}, request
            request.session[:no_landing_bounce_tracked] = true
          end
        end

        if !request.session[:visit_start].blank? && !request.session[:long_visit_tracked]
          if (Time.now-request.session[:visit_start]) > (Metrics::config[:long_visit_seconds] || 120).seconds
            track_metric :acquisition, :long_visit, {}, request
            request.session[:long_visit_tracked] = true
          end
        end
      end
    rescue => e
      metrics_error e
    end
  end

  def track_metric(event_type, event_name, options = {}, req = request)
    begin
      start = Time.now
      
      if !(request.user_agent =~ BOTS) && (!options[:per] || (options[:per] == :session && req.session["per_session_#{event_name}_#{event_type}"].blank?))
        options[:event_type] = event_type
        data = {}
        # data[:session] = req.session_options[:id]
        data.merge! options[:data] unless options[:data].blank?
        options[:data] = data
        MongoMetrics(req.env).track event_name, options
        req.session["per_session_#{event_name}_#{event_type}"] = true if options[:per] == :session
      end
      
      log_metrics_delay start, "track"
    rescue Exception => e
      metrics_error e
    end
  end

  def track_realtime(type, data = {}, options = {})
    begin
      if (defined?(request) && !(request.user_agent =~ BOTS)) || !defined?(request)
        start = Time.now
        options[:expire] ||= 60
    
        uuid = UUIDTools::UUID.random_create.to_s
    
        event = {:_type => type}
        event.merge! data
        event[:_session] = MongoMetrics(request.env).id || request.session_options[:id] if defined?(request) && options[:add_session]

        Metrics::realtime_connection.set "#{Metrics::realtime_config[:event_prefix]}-event-#{uuid}", event.to_json
        Metrics::realtime_connection.lpush "#{Metrics::realtime_config[:event_prefix]}-queue", uuid
        Metrics::realtime_connection.expire "#{Metrics::realtime_config[:event_prefix]}-event-#{uuid}", options[:expire]

        log_realtime_metrics_delay start, "track_realtime" if !options[:skip_log_delay]
      end
    rescue => e
      metrics_error e, 'Track realtime', true
    end
  end

  def get_user_metric_data(field, req = request)
    result = nil
    
    begin
      start = Time.now

      if !(request.user_agent =~ BOTS)
        metric_user = MongoMetrics(req.env).user({:fields => {"data.#{field}" => 1, '_id' => 0}})
        data = metric_user ? (metric_user['data'] || {}) : {}
        result = data[field.to_s]
      end
      
      log_metrics_delay start, "get_user_metric_data"
    rescue Exception => e
      metrics_error e
    end
    
    result
  end

  def set_user_metric_data(*args)
    begin
      start = Time.now
      
      if !(request.user_agent =~ BOTS)
        field = args[0]
        value = args[1]
        options = args[2] || {}
        req = args[3] || request

        overwrites = {}
        non_overwrites = {}
        
        if field.is_a?(Symbol) || field.is_a?(String)
          if options[:overwrite]
            overwrites["data.#{field.to_s}"] = value
          else
            non_overwrites["data.#{field.to_s}"] = value
          end
        else
          field.each do |field_hash|
            if field_hash[:overwrite]
              overwrites["data.#{field_hash[:key].to_s}"] = field_hash[:value]
            else
              non_overwrites["data.#{field_hash[:key].to_s}"] = field_hash[:value]
            end
          end
        end

        unless overwrites.empty?
          MongoMetrics(req.env).update("$set" => overwrites)
        end

        unless non_overwrites.empty?
          non_overwrites.each do |key, value|
            MongoMetrics(req.env).update_if_not_set(key, {'$set' => {key => value}})
          end
        end
        
      end
      
      log_metrics_delay start, "set_user_metric_data"
    rescue Exception => e
      metrics_error e
    end
  end

  def ab_convert!(conversion)
    begin
      start = Time.now

      if Metrics::config[:ab_framework] == :abongo
        bongo! conversion
      elsif Metrics::config[:ab_framework] == :abingo
        bingo! conversion
      end

      log_metrics_delay start, "ab_convert!"
    rescue Exception => e
      metrics_error e, 'AB Conversion'
    end
  end
  
  def ab_test_with_metrics(test_name, alternatives = nil, options = {})
    in_test = nil

    begin
      start = Time.now
    
      if Metrics::config[:ab_framework] == :abingo || Metrics::config[:ab_framework] == :abongo
        in_test = ab_test test_name, alternatives, options
      elsif Metrics::config[:ab_framework] == :vanity
        in_test = ab_test test_name
      else
        metrics_error "Invalid :ab_framework param passed to Metrics::init: #{Metrics::config[:ab_framework]}"
      end
  
      if !(request.user_agent =~ BOTS) && in_test
        set_user_metric_data "ab_tests.#{test_name}", in_test, :overwrite => true
      end

      log_metrics_delay start, "ab_test_with_metrics"
    rescue Exception => e
      metrics_error e
    end

    in_test ? in_test : (alternatives ? alternatives.first : nil)
  end

  def link_current_metrics_user(current_user)
    begin
      if current_user && get_user_metric_data(:current_user_id).blank?
        set_user_metric_data(:current_user_id, current_user.id.to_s, :overwrite => true)
      end
    rescue Exception => e
      metrics_error e
    end
  end
  
  def user_share_code
    get_user_metric_data(:share_code) || 'no'
  end
  
  def nps_voteable?
    begin
      if !Metrics::nps_config.empty? && (!Metrics::nps_config[:once_per_user] || (Metrics::nps_config[:once_per_user] && !get_user_metric_data("#{Metrics::nps_config[:event_name]}_voted")))
        votes = Metrics::nps_cache.get(Metrics::nps_config[:cache_cohort].call).to_i || 0
        return votes < Metrics::nps_config[:votes_needed]
      end
    rescue Exception => e
      metrics_error e, 'NPS voteable?'
    end
  
    false
  end

  def nps_vote(score)
    begin
      if nps_voteable?
        track_metric Metrics::nps_config[:event_type], Metrics::nps_config[:event_name], :data => {:score => score.to_i}
        set_user_metric_data "#{Metrics::nps_config[:event_name]}_voted".to_sym, score.to_i, :overwrite => true
    
        Metrics::nps_cache.add Metrics::nps_config[:cache_cohort].call, 0, nil, {:raw => true}
        Metrics::nps_cache.incr Metrics::nps_config[:cache_cohort].call
      
        track_realtime('nps_score', {:score => score.to_i}) if respond_to?(:track_realtime)
      end
    rescue Exception => e
      metrics_error e, 'NPS voting'
    end
  end
  
end