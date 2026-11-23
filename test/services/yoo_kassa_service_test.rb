require "test_helper"
require "json"

class YooKassaServiceTest < ActiveSupport::TestCase
  Response = Struct.new(:status, :body) do
    def success?
      status.between?(200, 299)
    end
  end

  Request = Struct.new(:headers, :body)

  class FakeConnection
    attr_reader :last_request, :last_path

    def initialize(response)
      @response = response
    end

    def post(path)
      @last_path = path
      @last_request = Request.new({})
      yield @last_request
      @response
    end

    def get(path)
      @last_path = path
      @last_request = Request.new({})
      yield @last_request
      @response
    end
  end

  def create_order
    Order.create!(name: "Тестовый покупатель", email: "buyer@example.com", address: "Москва", total: 125.50)
  end

  test "creates a redirect payment with the order amount and idempotence key" do
    order = create_order
    connection = FakeConnection.new(
      Response.new(201, {
        "id" => "payment-123",
        "confirmation" => { "confirmation_url" => "https://yookassa.example/pay/123" }
      })
    )
    service = YooKassaService.new(connection: connection, shop_id: "shop-1", secret_key: "secret")

    result = service.create_payment(order, return_url: "https://store.example/orders/#{order.to_param}")

    assert_equal "https://yookassa.example/pay/123", result
    assert_equal "/v3/payments", connection.last_path
    assert_equal order.payment_idempotence_key, connection.last_request.headers["Idempotence-Key"]
    request_body = JSON.parse(connection.last_request.body)
    assert_equal "RUB", request_body.dig("amount", "currency")
    assert_equal format("%.2f", order.total), request_body.dig("amount", "value")
    assert_equal "payment-123", order.reload.payment_id
  end

  test "marks order paid only after retrieving a matching successful payment" do
    order = create_order
    order.update!(payment_id: "payment-456")
    connection = FakeConnection.new(
      Response.new(200, {
        "id" => "payment-456",
        "status" => "succeeded",
        "amount" => { "value" => format("%.2f", order.total), "currency" => "RUB" },
        "metadata" => { "order_id" => order.id.to_s }
      })
    )
    service = YooKassaService.new(connection: connection, shop_id: "shop-1", secret_key: "secret")

    assert_equal "succeeded", service.sync_order_status(order)
    assert_equal "succeeded", order.reload.payment_status
  end

  test "does not mark an order paid when provider metadata does not match" do
    order = create_order
    order.update!(payment_id: "payment-789")
    connection = FakeConnection.new(
      Response.new(200, {
        "id" => "payment-789",
        "status" => "succeeded",
        "amount" => { "value" => format("%.2f", order.total), "currency" => "RUB" },
        "metadata" => { "order_id" => "another-order" }
      })
    )
    service = YooKassaService.new(connection: connection, shop_id: "shop-1", secret_key: "secret")

    assert_nil service.sync_order_status(order)
    assert_equal "pending", order.reload.payment_status
  end
end
