require "test_helper"

class CalculatorControllerTest < ActionDispatch::IntegrationTest
  test "visitors can open the AI assistant without signing in" do
    get calculator_path

    assert_response :success
    assert_select "h2", "ИИ-конструктор страниц"
    assert_select "textarea[name='prompt']"
    assert_select "textarea#ai-assistant-html"
    assert_select "iframe#ai-assistant-preview[sandbox]"
    assert_select "script", /fetch\("\/color-showcase\.html"\)/
  end

  test "color showcase page links each color to an association" do
    get "/color-showcase.html"

    assert_response :success
    assert_select "a.swatch[href]", 6
    assert_select "a[href='https://en.wikipedia.org/wiki/Chocolate']", text: "История шоколада"
    assert_select "a[href='https://en.wikipedia.org/wiki/Sturmabteilung']", text: "Краткая справка о СА"
  end

  test "visitors can generate and update an HTML page without signing in" do
    requests = []
    service = Object.new
    service.define_singleton_method(:ask) do |prompt, system:|
      requests << [ prompt, system ]
      "<!DOCTYPE html><html><body><button>Brown</button></body></html>"
    end

    original_new = AiService.method(:new)
    AiService.define_singleton_method(:new) { service }
    begin
      post calculator_ask_path, params: { prompt: "Привет" }, as: :json
    ensure
      AiService.define_singleton_method(:new, original_new)
    end

    assert_response :success
    assert_includes response.parsed_body["html"], "<button>Brown</button>"
    assert_includes requests.first.last, "полный самодостаточный HTML-документ"
  end

  test "existing HTML is included when asking for a page change" do
    received_prompt = nil
    service = Object.new
    service.define_singleton_method(:ask) do |prompt, system:|
      received_prompt = prompt
      "<html><body>Updated</body></html>"
    end

    original_new = AiService.method(:new)
    AiService.define_singleton_method(:new) { service }
    begin
      post calculator_ask_path, params: {
        prompt: "Добавь коричневую кнопку",
        html: "<html><body>Existing</body></html>"
      }, as: :json
    ensure
      AiService.define_singleton_method(:new, original_new)
    end

    assert_response :success
    assert_includes received_prompt, "<html><body>Existing</body></html>"
    assert_includes received_prompt, "Добавь коричневую кнопку"
  end

  test "blank prompts are rejected" do
    post calculator_ask_path, params: { prompt: " " }, as: :json

    assert_response :bad_request
    assert_equal "Пустой промпт", response.parsed_body["error"]
  end

  test "prompts longer than 4000 characters are rejected" do
    post calculator_ask_path, params: { prompt: "а" * 4_001 }, as: :json

    assert_response :unprocessable_entity
    assert_equal "Вопрос не должен превышать 4000 символов.", response.parsed_body["error"]
  end

  test "HTML longer than 20000 characters is rejected" do
    post calculator_ask_path, params: {
      prompt: "Измени страницу",
      html: "a" * 20_001
    }, as: :json

    assert_response :unprocessable_entity
    assert_equal "HTML-код не должен превышать 20000 символов.", response.parsed_body["error"]
  end
end
