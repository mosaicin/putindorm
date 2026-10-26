require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  test "index displays the product catalog and Journey music links" do
    sign_in_as(User.take)

    get root_path

    assert_response :success
    assert_select "link[href^='https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css']"
    assert_select "main.container"
    assert_select "section[aria-labelledby='journey-heading']"
    assert_select "a[href^='https://www.youtube.com/@journey/search']"
  end
end
