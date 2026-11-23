class OrdersController < ApplicationController
  require "json"
  require "uri"
  require "securerandom"

  allow_unauthenticated_access only: %i[ show pay webhook ]
  skip_forgery_protection only: :webhook

  def show
    @order = Order.find_by!(public_token: params[:token])
    if @order.payment_status == "pending" && @order.payment_id.present?
      YooKassaService.new.sync_order_status(@order)
    end
  rescue YooKassaService::PaymentError => e
    Rails.logger.warn("Could not refresh payment status for order #{@order.id}: #{e.message}")
  end

  def pay
    @order = Order.find_by!(public_token: params[:token])
    return redirect_to order_path(@order), notice: "Заказ уже оплачен." if @order.payment_status == "succeeded"

    if @order.payment_status == "canceled"
      @order.update!(
        payment_status: "pending",
        payment_id: nil,
        payment_url: nil,
        payment_idempotence_key: SecureRandom.uuid
      )
    end

    payment_url = YooKassaService.new.create_payment(@order, return_url: payment_return_url(@order))
    redirect_to payment_url, allow_other_host: true
  rescue YooKassaService::PaymentError => e
    Rails.logger.warn("Could not retry YooKassa checkout for order #{@order&.id}: #{e.message}")
    redirect_to order_path(@order), alert: "Не удалось перейти к оплате. Попробуйте позже."
  end

  def webhook
    notification = JSON.parse(request.raw_post)
    event = notification["event"]
    payment_id = notification.dig("object", "id")
    return head :ok unless %w[payment.succeeded payment.canceled].include?(event)
    return head :bad_request if payment_id.blank?

    order = Order.find_by(payment_id: payment_id)
    return head :not_found unless order

    payment_status = YooKassaService.new.sync_order_status(order)
    expected_status = event.delete_prefix("payment.")
    head(payment_status == expected_status ? :ok : :unprocessable_entity)
  rescue JSON::ParserError
    head :bad_request
  rescue YooKassaService::PaymentError => e
    Rails.logger.error("YooKassa webhook verification failed: #{e.message}")
    head :service_unavailable
  end

  private

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
end
