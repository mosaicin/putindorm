require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  test "index displays the public product catalog and Journey music links" do
    get root_path

    assert_response :success
    assert_select "a[href='#{new_product_path}']", false
    assert_select "link[href^='https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css']"
    assert_select "main.container"
    assert_select "section[aria-labelledby='assistant-heading']"
    assert_select "h2", "ИИ-конструктор страниц"
    assert_select "form[action='#{calculator_ask_path}']"
    assert_select "#payment-heading", "Удобная онлайн-оплата"
    assert_select "section[aria-labelledby='journey-heading']"
    assert_select "a[href^='https://www.youtube.com/@journey/search']"
  end

  test "visitors cannot create products" do
    get new_product_path

    assert_redirected_to new_session_path

    assert_no_difference("Product.count") do
      post products_path, params: { product: { name: "Public product" } }
    end

    assert_redirected_to new_session_path
  end

  test "visitors can view product details" do
    get product_path(products(:one))

    assert_response :success
    assert_select "h1", products(:one).name
    assert_select "form[action='#{add_to_cart_path(products(:one))}']"
  end

  test "signed-in non-admin users cannot manage products" do
    sign_in_as(users(:one))
    product = products(:one)

    get new_product_path
    assert_redirected_to root_path

    post products_path, params: { product: { name: "Unauthorized product" } }
    assert_redirected_to root_path

    get edit_product_path(product)
    assert_redirected_to root_path

    delete product_path(product)
    assert_redirected_to root_path
    assert Product.exists?(product.id)
  end

  test "admins can create and edit products" do
    admin = users(:one)
    admin.update!(admin: true)
    sign_in_as(admin)

    get new_product_path
    assert_response :success
    assert_select "button[data-action='product-description#generate']", "Создать черновик с ИИ"
    assert_select "form[data-product-description-url-value='#{generate_description_products_path}']"

    assert_difference("Product.count", 1) do
      post products_path, params: { product: { name: "Admin product", price: 12.5 } }
    end
    assert_redirected_to products_path

    product = Product.find_by!(name: "Admin product")
    patch product_path(product), params: { product: { name: "Updated product" } }
    assert_redirected_to product_path(product)
    assert_equal "Updated product", product.reload.name
  end

  test "only admins can generate a product description" do
    post generate_description_products_path, params: { name: "Настольная лампа" }, as: :json

    assert_redirected_to new_session_path

    sign_in_as(users(:one))
    post generate_description_products_path, params: { name: "Настольная лампа" }, as: :json

    assert_redirected_to root_path
  end

  test "description generation rejects a blank product name" do
    admin = users(:one)
    admin.update!(admin: true)
    sign_in_as(admin)

    post generate_description_products_path, params: { name: " " }, as: :json

    assert_response :unprocessable_entity
    assert_equal "Сначала укажите название товара.", response.parsed_body["error"]
  end
end
