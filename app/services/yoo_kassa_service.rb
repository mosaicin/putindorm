require "base64"
require "faraday"
require "json"

class YooKassaService
  class PaymentError < StandardError; end

  API_URL = "https://api.yookassa.ru"

  def initialize(connection: nil, shop_id: nil, secret_key: nil)
    @connection = connection || Faraday.new(url: API_URL) do |faraday|
      faraday.options.open_timeout = 5
      faraday.options.timeout = 15
    end
    @shop_id = shop_id || (ENV["YOOKASSA_SHOP_ID"] unless Rails.env.test?)
    @secret_key = secret_key || (ENV["YOOKASSA_SECRET_KEY"] unless Rails.env.test?)
  end

  def create_payment(order, return_url:)
    return order.payment_url if order.payment_url.present?

    shop_id, secret_key = credentials
    response = @connection.post("/v3/payments") do |request|
      request.headers["Authorization"] = basic_auth(shop_id, secret_key)
      request.headers["Content-Type"] = "application/json"
      request.headers["Idempotence-Key"] = order.payment_idempotence_key
      request.body = {
        amount: { value: format("%.2f", order.total), currency: "RUB" },
        capture: true,
        confirmation: { type: "redirect", return_url: return_url },
        description: "Заказ #{order.id}",
        metadata: { order_id: order.id.to_s }
      }.to_json
    end

    data = parse_response(response)
    payment_url = data.dig("confirmation", "confirmation_url")
    payment_id = data["id"]
    unless response.success? && payment_id.present? && payment_url.present?
      Rails.logger.error("YooKassa payment creation failed with HTTP #{response.status}")
      raise PaymentError, "Платёжный сервис не смог создать оплату."
    end

    order.update!(payment_id: payment_id, payment_url: payment_url)
    payment_url
  rescue Faraday::Error => e
    Rails.logger.error("YooKassa request failed: #{e.class}: #{e.message}")
    raise PaymentError, "Платёжный сервис временно недоступен."
  end

  def sync_order_status(order)
    return unless order.payment_id.present?

    shop_id, secret_key = credentials
    response = @connection.get("/v3/payments/#{order.payment_id}") do |request|
      request.headers["Authorization"] = basic_auth(shop_id, secret_key)
      request.headers["Accept"] = "application/json"
    end
    payment = parse_response(response)

    unless response.success?
      Rails.logger.error("YooKassa payment lookup failed with HTTP #{response.status}")
      raise PaymentError, "Не удалось проверить статус платежа."
    end

    return unless valid_payment_for_order?(payment, order)

    status = payment["status"]
    order.update!(payment_status: status) if %w[succeeded canceled].include?(status) && order.payment_status != status
    status
  rescue Faraday::Error => e
    Rails.logger.error("YooKassa status check failed: #{e.class}: #{e.message}")
    raise PaymentError, "Не удалось проверить статус платежа."
  end

  private

  def credentials
    return [ @shop_id, @secret_key ] if @shop_id.present? && @secret_key.present?

    raise PaymentError, "Платёжный сервис не настроен."
  end

  def basic_auth(shop_id, secret_key)
    "Basic #{Base64.strict_encode64("#{shop_id}:#{secret_key}")}"
  end

  def parse_response(response)
    return response.body if response.body.is_a?(Hash)

    JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end

  def valid_payment_for_order?(payment, order)
    amount = payment.dig("amount", "value").to_d
    payment["id"] == order.payment_id &&
      payment.dig("metadata", "order_id") == order.id.to_s &&
      payment.dig("amount", "currency") == "RUB" &&
      amount == order.total
  end
end
