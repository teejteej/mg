Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
end

SURVEY = 'survey_250614'

if ENV['use_queue'] == 'true'
  Metrics::init('localhost', 27017, 'temp_metrics', {:no_bounce_seconds => 10, :long_visit_seconds => 120, :log_delays => true, :log_delays_as_realtime_event => 'metrics_delay', :log_delays_realtime_sample => 0.02, :log_errors_as_realtime_event => 'metrics_error', :ab_framework => :abongo, :use_queue => true, :queue_workers => ENV['queue_workers'].to_i, :log_queue_size => true, :log_queue_size_sample => 1.0})
else
  Metrics::init('localhost', 27017, 'temp_metrics', {:no_bounce_seconds => 10, :long_visit_seconds => 120, :log_delays => true, :log_delays_as_realtime_event => 'metrics_delay', :log_delays_realtime_sample => 0.02, :log_errors_as_realtime_event => 'metrics_error', :ab_framework => :abongo, :use_queue => false})
end

# Metrics::init_realtime('localhost', 6379, {:event_prefix => 'temp_metrics', :log_delays => false, :log_delays_as_realtime_event => 'realtime_metrics_delay', :log_delays_realtime_sample => 0.02, :use_queue => true})

Metrics::init_survey('nps', {:global_one_survey_per_user => true, :votes_needed => 500, :event_name => 'nps_score_1', :event_type => 'nps_score', :cache_cohort => proc{"nps_score_#{Time.now.strftime('%V')}_#{Time.now.year}"}, :once_per_user => true, :cache_server => '127.0.0.1:11211'})
Metrics::init_survey('pmf', {:global_one_survey_per_user => true, :votes_needed => 500, :event_name => 'pmf_score_1', :event_type => 'pmf_score', :cache_cohort => proc{"pmf_score_#{Time.now.strftime('%V')}_#{Time.now.year}"}, :once_per_user => true, :cache_server => '127.0.0.1:11211'})
Metrics::init_survey(SURVEY, {:global_one_survey_per_user => true, :votes_needed => 100000, :event_name => SURVEY, :event_type => SURVEY, :cache_cohort => proc{SURVEY}, :once_per_user => true, :cache_server => '127.0.0.1:11211'})

Abongo.db = Mongo::Connection.new('localhost', 27017)['temp_abongo']

# Clean-up for test
MongoMetrics::users.drop
MongoMetrics::events.drop