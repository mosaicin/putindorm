require "application_system_test_case"

class StoreTest < ApplicationSystemTestCase
  test "visitor can browse the product catalog and Journey songs" do
    visit root_path

    assert_text "Products"
    assert_text "Journey"
    assert_link "Слушать на YouTube"
  end
end
