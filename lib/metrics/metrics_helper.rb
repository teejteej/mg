module MetricsHelper

  BOTS = /\b(Baidu|Gigabot|Googlebot|libwww-perl|lwp-trivial|msnbot|pingdom|SiteUptime|Slurp|WordPress|ZIBB|ZyBorg)\b/i

  def log_metrics_delay(start, method)
    puts "#{method} metrics time: #{(Time.now-start)*1000} ms" if Metrics::config[:log_delays]
  end

  def metrics_error(e)
    if Rails.respond_to?('env') && Rails.env.development?
      raise e
    else
      puts "Track metric error: #{e}"
    end
  end
  
  def set_metrics_identity
    begin
      start = Time.now
      
      if !(request.user_agent =~ BOTS)    
        unless cookies[AARRR::Config.cookie_name]
          AARRR(request.env).set_cookie(response)
          data = [
            {:key => :first_visit, :value => Time.now, :overwrite => false}, 
            {:key => :share_code, :value => (("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a).sort_by{rand}[0,7].join, :overwrite => false},
            {:key => :first_visit_referrer, :value => request.env['HTTP_REFERER'], :overwrite => false}
          ]
          data << {:key => :first_visit_source, :value => params[:src], :overwrite => false} unless params[:src].blank?
          set_user_metric_data data
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
            track :acquisition, :no_landing_bounce, {}, request
            request.session[:no_landing_bounce_tracked] = true
          end
        end

        if !request.session[:visit_start].blank? && !request.session[:long_visit_tracked]
          if (Time.now-request.session[:visit_start]) > (Metrics::config[:long_visit_seconds] || 120).seconds
            track :acquisition, :long_visit, {}, request
            request.session[:long_visit_tracked] = true
          end
        end

        unless request.params['vt'].blank?
          track :referral, :referrer, {:referral_code => request.params['vt'][0..10]}, request
        end
      end
    rescue => e
      metrics_error e
    end
  end

  def track(event_type, event_name, options = {}, req = request)
    begin
      start = Time.now
      
      if !(request.user_agent =~ BOTS) && (!options[:per] || (options[:per] == :session && req.session["per_session_#{event_name}_#{event_type}"].blank?))
        options[:event_type] = event_type
        data = {}
        data[:session] = req.session_options[:id]
        data.merge! options[:data] unless options[:data].blank?
        options[:data] = data
        AARRR(req.env).track event_name, options
        req.session["per_session_#{event_name}_#{event_type}"] = true if options[:per] == :session
      end
      
      log_metrics_delay start, "track"
    rescue Exception => e
      metrics_error e
    end
  end

  def track!(event_type, event_name, options = {})
    options[:complete] = true
    track event_type, event_name, options
  end

  def get_user_metric_data(field, req = request)
    begin
      start = Time.now

      if !(request.user_agent =~ BOTS)        
        metric_user = AARRR(req.env).user
        pp "mu: #{metric_user}"
        data = metric_user ? (metric_user['data'] || {}) : {}
        data[field.to_s]
      end
      
      log_metrics_delay start, "get_user_metric_data"
    rescue Exception => e
      metrics_error e
    end
  end

  def set_user_metric_data(*args)
    begin
      start = Time.now
      
      if !(request.user_agent =~ BOTS)
        field = args[0]
        value = args[1]
        options = args[2] || {}
        req = args[3] || request

        metric_user = AARRR(req.env).user
        data = metric_user ? (metric_user['data'] || {}) : {}

        if field.is_a? Symbol
          if options[:overwrite] || (!options[:overwrite] && data[field.to_s].blank?)
            data[field.to_s] = value
            AARRR(req.env).set_data data
          end
        else
          field.each do |field_hash|
            if field_hash[:overwrite] || (!field_hash[:overwrite] && data[field.to_s].blank?)
              data[field_hash[:key].to_s] = field_hash[:value]
            end
          end
          AARRR(req.env).set_data data
        end
      end
      
      log_metrics_delay start, "set_user_metric_data"
    rescue Exception => e
      metrics_error e
    end
  end

  def ab_test_with_metrics(test_name, alternatives = nil, options = {})
    in_test = ab_test test_name, alternatives, options
  
    begin
      if !(request.user_agent =~ BOTS)
        ab_tests = get_user_metric_data(:ab_tests) || {}
        if ab_tests[test_name].blank?
          ab_tests[test_name] = in_test
          set_user_metric_data :ab_tests, ab_tests
        end
      end
    rescue Exception => e
      metrics_error e
    end
  
    in_test
  end

  def link_current_metrics_user(current_user)
    begin
      if current_user && get_user_metric_data(:current_user_id).blank?
        set_user_metric_data(:current_user_id, current_user.id.to_s)
      end
    rescue Exception => e
      metrics_error e
    end
  end
  
  def user_share_code
    get_user_metric_data(:share_code) || 'no'
  end
  
end