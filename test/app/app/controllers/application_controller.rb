class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  
  before_filter :set_abongo_identity

  before_filter :set_metrics_identity, :except => [:test_results]

  def set_abongo_identity
    if (request.user_agent.blank? || request.user_agent =~ BOTS) #This prevents robots from occupying more than 1 participant slot in A/B tests.
      Abongo.identity = 'robot'
    else
      if cookies[:abongo_identity]
        Abongo.identity = cookies[:abongo_identity]
      else
        abongo_identity = rand(10 ** 10).to_i.to_s
        cookies[:abongo_identity] = {:value => abongo_identity, :expires => 2.years.from_now}
        Abongo.identity = abongo_identity
      end
    end
  end
  
end
