Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  # Товары
  get  "/products",     to: "products#index"
  get  "/products/new", to: "products#new"      # ← добавили
  post "/products",     to: "products#create"

  # Калькулятор через ИИ
  get  "/calculator",     to: "calculator#index"   # ← добавили
  post "/calculator/ask", to: "calculator#ask"     # ← добавили

  get  "/agent",          to: "agent#index"
  post "/agent/proposals", to: "agent#create"
  post "/agent/proposals/:id/apply", to: "agent#apply"
end
