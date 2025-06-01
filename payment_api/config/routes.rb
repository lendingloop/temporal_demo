Rails.application.routes.draw do
  get '/health', to: 'payments#health'
  
  resources :payments, only: [:create, :show], path: '/api/payments'
end
