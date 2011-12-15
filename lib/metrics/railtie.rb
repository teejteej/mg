require 'metrics/metrics_helper'
include MetricsHelper

module Metrics

  ActionController::Base.send :include, MetricsHelper
  ActionView::Base.send :include, MetricsHelper
  
end