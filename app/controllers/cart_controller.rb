class CartController < ApplicationController
  require "uri"

  allow_unauthenticated_access

  def index
    @cart_items = cart_items
    @total = cart_total
  end

  def add
    product = Product.find(params[:product_id])
    quantity = params[:quantity].to_i
    quantity = 1 if quantity <= 0

    cart[product.id.to_s] = cart.fetch(product.id.to_s, 0).to_i + quantity
    redirect_to cart_path, notice: "#{product.name} добавлен в корзину."
  end

  def update
    product = Product.find(params[:product_id])
    quantity = params[:quantity].to_i
    if quantity <= 0
      cart.delete(product.id.to_s)
    else
      cart[product.id.to_s] = quantity
    end

    redirect_to cart_path, notice: "Корзина обновлена."
  end

  def remove
    product = Product.find(params[:product_id])
    cart.delete(product.id.to_s)
    redirect_to cart_path, notice: "#{product.name} удалён из корзины."
  end

  def checkout
    @cart_items = cart_items
    @total = cart_total

    if @cart_items.empty?
      redirect_to cart_path, alert: "Корзина пуста."
      return
    end

    if @total <= 0
      redirect_to cart_path, alert: "Сумма заказа должна быть больше нуля."
      return
    end

    @order = Order.new(order_params.merge(total: @total))
    begin
      Order.transaction do
        @order.save!
        @cart_items.each do |item|
          @order.order_items.create!(
            product: item[:product],
            quantity: item[:quantity],
            unit_price: item[:product].price
          )
        end
      end
    rescue ActiveRecord::RecordInvalid
      render_checkout_errors
      return
    end

    session[:cart] = {}

    begin
      payment_url = YooKassaService.new.create_payment(@order, return_url: payment_return_url(@order))
      redirect_to payment_url, allow_other_host: true
    rescue YooKassaService::PaymentError => e
      Rails.logger.warn("Could not start YooKassa checkout for order #{@order.id}: #{e.message}")
      redirect_to order_path(@order), alert: "Заказ сохранён, но оплату пока начать не удалось. Попробуйте ещё раз."
    end
  end

  private

  def render_checkout_errors
    @cart_items = cart_items
    @total = cart_total
    render :index, status: :unprocessable_entity
  end

  def payment_return_url(order)
    app_url = ENV["APP_URL"].presence
    if Rails.env.production? && app_url.blank?
      raise YooKassaService::PaymentError, "APP_URL is not configured."
    end

    base_url = app_url || request.base_url
    URI.join("#{base_url.chomp("/")}/", order_path(order)).to_s
  rescue URI::InvalidURIError
    raise YooKassaService::PaymentError, "APP_URL is invalid."
  end

  def order_params
    params.require(:order).permit(:name, :email, :phone, :address)
  end
end
