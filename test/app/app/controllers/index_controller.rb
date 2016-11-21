class IndexController < ApplicationController
  
  def landing
    session[:from_src] = params[:src] unless params[:src].blank?

    if !params[:ck].blank?
      set_user_metric_data :creative_keyword, params[:ck], :overwrite => true
    end

    set_user_metric_data :user_type, (params[:entry] || 'default'), :overwrite => false

    track_metric :metric, :visit_landing_page
    track_realtime 'landing_visit'
    
    render :text => 'Welcome', :layout => false
  end
  
  def signup
    track_metric :metric, :signup
    
    render :text => 'Signup', :layout => false
  end

  def test_results
    sleep 3
    
    missing_key = false

    users_needs_keys = %w(first_visit first_visit_ip first_visit_referrer last_request_at share_code first_visit_source creative_keyword)
    events_needs_keys = %w(aarrr_user_id event_name event_type data referral_code user_agent created_at)

    user_ids = []
    
    MongoMetrics::users.find.each do |u|
      user_ids << u['_id'].to_s

      if !u['data']
        missing_key = true
      else
        users_needs_keys.each do |key|
          if !u['data'].has_key?(key)
            missing_key = true
          end
        end
        
        missing_key = true if u['data']['creative_keyword'] != 'web1'
        missing_key = true if u['data']['first_visit_ip'] != '127.0.0.1'
        missing_key = true if u['data']['first_visit_referrer'] != nil
        missing_key = true if u['data']['first_visit_source'] != 'matrix'
        missing_key = true if u['data']['user_type'] != 'default'
      end
    end

    MongoMetrics::events.find.each do |e|
      events_needs_keys.each do |key|
        if !e.has_key?(key)
          missing_key = true
        end
      end

      missing_key = true if !user_ids.include?(e['aarrr_user_id'])
      
      missing_key = true if !(e['event_name'] == 'visit_landing_page' || e['event_name'] == 'signup')
      missing_key = true if e['event_type'] != 'metric'
      missing_key = true if e['data'] != {}
      missing_key = true if e['referral_code'] != nil
      missing_key = true if !e['user_agent'].include?('Mozilla')
    end
    
    success = !missing_key && MongoMetrics::users.count == params[:should_users_count].to_i && MongoMetrics::events.count == params[:should_events_count].to_i
    
    render :text => success, :layout => false
  end

end