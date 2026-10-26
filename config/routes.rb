Rails.application.routes.draw do
  root "products#index"

  resource :session
  resources :passwords, param: :token

  resources :products

  # Калькулятор через ИИ
  get  "/calculator",     to: "calculator#index"   # ← добавили
  post "/calculator/ask", to: "calculator#ask"     # ← добавили

  get  "/agent",          to: "agent#index"
  post "/agent/proposals", to: "agent#create"
  post "/agent/proposals/:id/apply", to: "agent#apply"
end
