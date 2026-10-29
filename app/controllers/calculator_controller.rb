class CalculatorController < ApplicationController
  MAX_PROMPT_LENGTH = 4_000
  MAX_HTML_LENGTH = 20_000
  SYSTEM_PROMPT = <<~PROMPT.freeze
    Ты конструктор веб-страниц. Создавай или изменяй HTML-страницу по запросу пользователя.
    Верни только полный самодостаточный HTML-документ с CSS внутри <style>, без Markdown-ограждений и пояснений.
    Для запрошенных ссылок добавляй работающие <a href="..."> элементы с подходящими адресами.
    Не добавляй JavaScript, внешние ресурсы, формы отправки или сетевые запросы.
    Сохраняй исходный дизайн и содержимое, если пользователь не просит их изменить.
  PROMPT

  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :ask, with: -> {
    render json: { error: "Слишком много запросов. Попробуйте позже." }, status: :too_many_requests
  }

  def index
  end

  def ask
    prompt = params[:prompt].to_s.strip

    if prompt.blank?
      return render json: { error: "Пустой промпт" }, status: :bad_request
    end

    if prompt.length > MAX_PROMPT_LENGTH
      return render json: { error: "Вопрос не должен превышать #{MAX_PROMPT_LENGTH} символов." }, status: :unprocessable_entity
    end

    html = params[:html].to_s
    if html.length > MAX_HTML_LENGTH
      return render json: { error: "HTML-код не должен превышать #{MAX_HTML_LENGTH} символов." }, status: :unprocessable_entity
    end

    request = if html.present?
      "Текущая HTML-страница:\n```html\n#{html}\n```\n\nИзмени её по запросу пользователя: #{prompt}"
    else
      prompt
    end

    answer = AiService.new.ask(request, system: SYSTEM_PROMPT)
    return render json: { error: "ИИ временно не ответил. Попробуйте позже." }, status: :service_unavailable unless answer

    generated_html = answer.match(/```(?:html)?\s*(.*?)```/im)&.captures&.first || answer
    generated_html = generated_html.strip

    unless generated_html.match?(/<(?:!doctype\s+html|html\b|head\b|body\b)/i)
      return render json: { error: "ИИ вернул не HTML-страницу. Попробуйте уточнить запрос." }, status: :bad_gateway
    end

    render json: { html: generated_html }
  end
end
