# (Optional) Installing without Gemfile
	- http://raflabs.com/blogs/silence-is-foo/2010/07/19/installing-a-gem-fork-from-github-source/

# Add to your Gemfile

	gem 'metrics', :git => 'git://github.com/teejteej/mg.git'

	gem 'mongo'
	gem 'bson_ext'
	gem 'redis'
	gem 'dalli'
	gem 'kgio'
	gem 'uuidtools'

# Add to your ApplicationController

	- `before_filter :set_metrics_identity`
	- `before_filter :track_extra_metrics`. (Optional) This track the viral referrers, no bounces and happy visits.

# Tracking metrics

	- Add to your environment: `Metrics::init('localhost', 27017, 'metrics', {:no_bounce_seconds => 10, :long_visit_seconds => 120, :log_delays => true, :log_delays_as_realtime_event => 'metrics_delay', :log_delays_realtime_sample => 0.1, :log_errors_as_realtime_event => 'metrics_error'})`
		- Where `log_delays`, `log_delays_as_realtime_event`, `log_delays_realtime_sample` and `log_errors_as_realtime_event` are optional configuration parameters.
		- `exception_on_init_fail` can be set `true` to all `init` methods methods, to raise exceptions when connection on initialization fails. Defaults to `false`.
	- `track_metric :activation, 'some_event'`
	- `track_metric :activation, :some_event`
	- `track_metric 'some_category', 'some_event', :data => {'param1' => 'value1'}`
	- `set_user_metric_data :flash_version, '11.2'` or `set_user_metric_data({'flash_version' => '11.2'})`. Set extra data for user in metrics, like flash version, age, etc. __Note__: the first param (key) must always be a symbol (`"something".to_sym`).
	- `set_user_metric_data :flash_version, '11.2', :overwrite => true`. Overwrite the value, even if it exist already. Defaults to false (not overwrite the value if the key already exists). If the key doesn't exists yet, default is to write it.
	- `[{:key => :some_param_1, :value => 'some_value_1', :overwrite => false}, {:key => :some_param_2, :value => 'some_value_2', :overwrite => false}]`. Set multiple key/values at once.
	- `link_current_metrics_user current_user`. Links current_user from the app db to the metrics user. Note that current_user must have an `id` method.
	- `user_share_code`. Return the share code for this user. To be used like this: `http://www.yourapp.com/?vt=<%= user_share_code %>`, or any other url. As long as the param `vt` is set, it will get tracked as a viral referrer.

	- Optional:
	    - To track landing bounces and long visits, use this at your landing action: `session[:visit_start] ||= Time.now`
	    - When using a/b testing, init your environment like this (where `:ab_framework` can be `:vanity`, `:abingo` or `:abongo`):
	        - `Metrics::init('localhost', 27017, 'metrics', {:no_bounce_seconds => 10, :long_visit_seconds => 120, :log_delays => true, :ab_framework => :abongo})`
	        - Then to run any a/b test and also set in metrics which variation this use has seen use `ab_test_with_metrics 'some_test', ['var1, 'var2'], :conversion => 'some_conversion'`

# A/B testing & keeping track of this in metrics
	- `ab_test_with_metrics 'test1', ['var1', 'var2'], :conversion => 'test1_converted'`. This will do an A/B test, and store the seen variation for the experiment with the metric user.
	- `ab_convert! 'test1'`. This will track a conversion for test1.

# Tracking realtime metrics

	- `Metrics::init_realtime('localhost', 6379, {:event_prefix => 'fnordmetric', :log_delays => false, :log_delays_as_realtime_event => 'realtime_metrics_delay', :log_delays_realtime_sample => 0.1})`
		- Where `log_delays`, `log_delays_as_realtime_event` and `log_delays_realtime_sample` are optional configuration parameters.
	- `track_realtime 'pageview', {}, :add_session => true`. Track realtime, unique per session (visitors per day in this case; not unique visitors per day)
	- `track_realtime 'some_realtime_event'`
	- `track_realtime('some_realtime_event', {:my_param => 'my_value'})`. Track realtime with extra parameter, that can be used in realtime backend.

# Tracking NPS survey metrics

- `Metrics::init_nps({:votes_needed => 200, :event_name => 'nps_score_1', :event_type => 'nps_score', :cache_cohort => proc{"nps_score_#{Time.now.month}_#{Time.now.year}"}, :once_per_user => true, :cache_server => '127.0.0.1:11211'})`
- _Note:_ `event_name` also functions as unique identification to see if the users already voted or not. If `config[:once_per_user] == true`, and we change event_name after the user has voted once already, he can vote again.
- `nps_voteable?`. Can the user vote, based on the init_nps configuration?
- `nps_vote(3)`. Score the NPS vote.

# Misc.

- In each `Metrics::init` or `Metrics::init_realtime`, two extra options can be added:
	- `:log_delays_as_realtime_event => 'metrics_delay', :log_delays_realtime_sample => 0.1`
	- If these two are set, the time needed to call `track_metric` or `track_realtime` is automatically tracked as a realtime event, with the delay in MS as extra parameter to track in the fnordmetric event handler.
	- `log_delays_realtime_sample => 0.1` means that only 1/10th of all calls to track / track_realtime are sampled with a delay, using 1.0 would mean all is sampled.
