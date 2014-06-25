Rails.application.routes.draw do
  root 'index#landing'
  
  get '/signup' => 'index#signup'
  get '/test_results' => 'index#test_results'
end
