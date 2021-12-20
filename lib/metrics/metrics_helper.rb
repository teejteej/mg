module MetricsHelper

  BOTS = /(bot|^$|spider|AACrawler|HttpClient|SWRLinkchecker|NING|Kimengi|InAGist|Extractor-Engine|AACrawler|SWRLinkchecker|W3C_Validator|wget|curl|Trend Micro|facebookexternalhit|URL Control|panopta|FlaxCrawler|YahooCacheSystem|xenu link|VB Project|ruby|rganalytics|MFE_expand|AppEngine-Google|DailyPerfect|lwp-request|Mail.RU|PageGetter|Harvester|unshort.me|UnwindFetchor|Mediapartners|MetaURI|JS-Kit|urlresolver|RockMeltEmbedService|LongURL|PostRank|ia_archiver|Summify|urllib|Baidu|Gigabot|Googlebot|libwww-perl|lwp-trivial|msnbot|pingdom|SiteUptime|Slurp|WordPress|ZIBB|ZyBorg)/i

  def init_check
    sess = TrackMetrics request.env
    sess.set_cookie response
  end
  
  def log_metrics_delay(start, method)
    # delay = (Time.now - start) * 1000
    #
    # if Metrics::config[:log_delays]
    #   Metrics::logger.info "#{method} metrics time: #{delay} ms" if Metrics::logger
    # end
  end

  def log_realtime_metrics_delay(start, method)
    # delay = (Time.now - start) * 1000
    #
    # if Metrics::realtime_config[:log_delays]
    #   Metrics::logger.info "#{method} realtime metrics time: #{delay} ms" if Metrics::logger
    # end
  end

  def metrics_error(e, type = 'Track', skip_track_realtime = false)
    if defined?(Rails) && Rails.env.development?
      raise e
    else
      Metrics::logger.error "#{type} metric error: #{e}" if Metrics::logger
    end
  end
  
  def set_metrics_identity
    begin
      init_check
    rescue
    end
    
    # begin
    #   start = Time.now
    #
    #   if !(request.user_agent =~ BOTS)
    #     if !cookies[TrackMetrics::Config.cookie_name]
    #
    #       share_code = (("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a).sort_by{rand}[0,7].join
    #
    #       TrackMetrics(request.env).set_cookie(response)
    #
    #       request.env['trackmetrics.extra'] = share_code
    #       cookies['_utmextr'] = {:value => share_code, :path => '/', :expires => Time.now+TrackMetrics::Config.cookie_expiration}
    #
    #       data = [
    #         {:key => :first_visit, :value => Time.now.utc, :overwrite => true},
    #         {:key => :share_code, :value => share_code, :overwrite => true},
    #         {:key => :first_visit_ip, :value => request.remote_ip, :overwrite => true},
    #         {:key => :first_visit_referrer, :value => request.env['HTTP_REFERER'], :overwrite => true}
    #       ]
    #       data << {:key => :first_visit_source, :value => params[:src], :overwrite => true} unless params[:src].blank?
    #       set_user_metric_data data
    #
    #       track_metric :referral, :referrer, {:referral_code => request.params['vt'][0..10]}, request unless request.params['vt'].blank?
    #       request.session[:first_visit] = true
    #     end
    #   end
    #
    #   log_metrics_delay start, "set_metrics_identity"
    # rescue => e
    #   metrics_error e
    # end
  end

  def track_extra_metrics
    begin
      init_check
    rescue
    end
  end

  def track_metric(event_type, event_name, options = {}, req = request)
    begin
      init_check
      
      start = Time.now

      if event_type == :metric
        use_event_name = event_name.to_s
        props = (options || {})[:data]
      else
        use_event_name = event_type.to_s
        props = {}

        if (options || {})[:data].present? && (options || {})[:data].is_a?(Hash)
          props = props.merge((options || {})[:data])
        elsif (options || {})[:data].present? && (options || {})[:data].is_a?(String)
          props["data"] = (options || {})[:data]
        end
        
        if event_name.present?
          if event_name.is_a?(Hash)
            props = props.merge(event_name)
          else
            if props["data"].present?
              props["data2"] = event_name
            else
              props["data"] = event_name
            end
          end
        end
      end
      
      if !(request.user_agent =~ BOTS) && (!options[:per] || (options[:per] == :session && req.session["per_session_#{use_event_name}_#{event_type}"].blank?))
        options[:event_type] = event_type
        data = {}
        # data[:session] = req.session_options[:id]
        data.merge! options[:data] if !options[:data].blank? && options[:data].is_a?(Hash)
        options[:data] = data

        options["props"] = props
        
        options["url"] = req.original_url
        options["ip"] = req.remote_ip
        options["referrer"] = req.env['HTTP_REFERER']

        TrackMetrics(req.env).track use_event_name, options
        req.session["per_session_#{use_event_name}_#{event_type}"] = true if options[:per] == :session
      end
      
      log_metrics_delay start, "track"
    rescue Exception => e
      metrics_error e
    end
  end

  def track_realtime(type, data = {}, options = {})
    begin
      init_check
    end
  end

  def get_user_metric_data(field, req = request)
  end

  def set_user_metric_data(*args)
    begin
      init_check
      
      if !(request.user_agent =~ BOTS)
        properties = {}
      
        if args[0].is_a?(Hash)
          properties = args[0]
        elsif args[0].is_a?(Symbol) || args[0].is_a?(String)
          properties[args[0]] = args[1]
        elsif args[0].is_a?(Array)
          args[0].each do |item|
            properties[item[:key]] = item[:value]
          end
        end
        
        options = {}
        options["url"] = request.original_url
        options["ip"] = request.remote_ip
        options["user_agent"] = request.env["HTTP_USER_AGENT"]&.to_s
        options["referrer"] = request.env['HTTP_REFERER']
        options["timestamp"] = Time.now.getutc

        TrackMetrics(request.env).update properties, options
      end
    rescue Exception => e
      metrics_error e
    end
  end

  def ab_convert!(conversion)
    begin
      init_check
      track_metric :metric, conversion&.to_s
    rescue Exception => e
      metrics_error e, 'AB Conversion'
    end
  end
  
  def ab_test_with_metrics(test_name, alternatives = nil, options = {})
    begin
      init_check

      if alternatives && defined?(Rails) && Rails.env.test?
        return alternatives.first
      end

      unless params[:ab_test].blank?
        if params[:ab_test] == test_name
          return params[:ab_var]
        end
      end

      if alternatives && defined?(Rails) && Rails.env.test?
        return alternatives.first
      end
      
      metrics_env = TrackMetrics(request.env)      
    	result = Zlib.crc32 "#{metrics_env.id}_#{test_name}"
	
    	if result % 2 == 0
    		alternative = alternatives[0]
    	else
    		alternative = alternatives[1]
    	end
      
      set_user_metric_data({"experiments" => {test_name => alternative}})
      alternative
    rescue => e
      metrics_error e
      
      if defined?(Rails) && Rails.env.development?
        raise e
      else
        return alternatives.first
      end
    end
  end

  def link_current_metrics_user(current_user)
    begin
      init_check

      if current_user
        options = {}
        options["url"] = request.original_url
        options["ip"] = request.remote_ip
        options["user_agent"] = request.env["HTTP_USER_AGENT"]&.to_s
        options["referrer"] = request.env['HTTP_REFERER']
        options["timestamp"] = Time.now.getutc
        
        TrackMetrics(request.env).identify_user current_user, options, response
      end
    rescue Exception => e
      metrics_error e
    end
  end
  
  def user_share_code
    init_check

    request.env['trackmetrics.extra'] || request.cookies['_utmextr'] || 'no' rescue 'no'
  end
  
  def survey_voteable?(type)
    false
  end

  def survey_vote(type, score)
  end
  
end
