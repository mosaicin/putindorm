require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  test "index displays the public product catalog and Journey music links" do
    get root_path

    assert_response :success
    assert_select "a[href='#{new_product_path}']", "New product"
    assert_select "link[href^='https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css']"
    assert_select "main.container"
    assert_select "section[aria-labelledby='assistant-heading']"
    assert_select "h2", "ИИ-конструктор страниц"
    assert_select "form[action='#{calculator_ask_path}']"
    assert_select "section[aria-labelledby='journey-heading']"
    assert_select "a[href^='https://www.youtube.com/@journey/search']"
  end

  test "visitors can open and submit the new product form without signing in" do
    get new_product_path

    assert_response :success
    assert_select "h1", "New product"
    assert_select "form[action='#{products_path}']"

    assert_difference("Product.count", 1) do
      post products_path, params: { product: { name: "Public product" } }
    end

    assert_redirected_to products_path
    follow_redirect!
    assert_response :success
    assert_select "#products", text: /Public product/
  end

  test "visitors still need to sign in to edit or delete products" do
    product = products(:one)

    get edit_product_path(product)
    assert_redirected_to new_session_path

    delete product_path(product)
    assert_redirected_to new_session_path
    assert Product.exists?(product.id)
  end
end
