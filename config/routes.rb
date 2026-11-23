Rails.application.routes.draw do
  root "products#index"

  resource :session
  resources :passwords, param: :token

  get "/cart", to: "cart#index", as: :cart
  post "/cart/add/:product_id", to: "cart#add", as: :add_to_cart
  patch "/cart/update/:product_id", to: "cart#update", as: :update_cart_item
  delete "/cart/remove/:product_id", to: "cart#remove", as: :remove_from_cart
  post "/cart/checkout", to: "cart#checkout", as: :checkout_cart
  post "/yookassa/webhook", to: "orders#webhook", as: :yookassa_webhook

  resources :products do
    post :generate_description, on: :collection
  end
  resources :orders, only: :show, param: :token do
    post :pay, on: :member
  end

  # Калькулятор через ИИ
  get  "/calculator",     to: "calculator#index"
  post "/calculator/ask", to: "calculator#ask"

  get  "/agent",          to: "agent#index"
  post "/agent/proposals", to: "agent#create"
  post "/agent/proposals/:id/apply", to: "agent#apply"
end
