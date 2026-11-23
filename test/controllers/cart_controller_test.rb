require "test_helper"

class CartControllerTest < ActionDispatch::IntegrationTest
  test "visitors can add products to the cart and place an order" do
    product = products(:one)
    product.update!(price: 100)

    post add_to_cart_path(product)
    assert_response :redirect
    assert_equal 1, session[:cart][product.id.to_s].to_i

    post checkout_cart_path, params: {
      order: {
        name: "Иван Иванов",
        email: "ivan@example.com",
        phone: "+79990001122",
        address: "Москва, Тверская 1"
      }
    }

    order = Order.last
    assert_redirected_to order_path(order)
    assert_equal 1, Order.count
    assert_equal product.name, order.order_items.first.product.name

    get order_path(order)
    assert_response :success
    assert_select "h1", "Заказ ##{order.id}"
    assert_select "body", text: /ivan@example\.com/, count: 0
    assert_select "body", text: /Тверская/, count: 0
  end
end
