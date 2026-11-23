require "openai"

class AiDescriptionService
  MODEL = "openai/gpt-oss-20b"

  def generate_description(product_name, category: nil)
    key = api_key
    if key.blank?
      Rails.logger.warn("Groq API key is not configured; using local fallback description.")
      return fallback_description(product_name, category)
    end

    response = OpenAI::Client.new(
      uri_base: "https://api.groq.com/openai",
      access_token: key
    ).chat(
      parameters: {
        model: MODEL,
        messages: [
          {
            role: "system",
            content: "Ты помощник интернет-магазина. Пиши точные, привлекательные описания товаров на русском языке в 2–3 предложениях. Не выдумывай характеристики, которых нет во входных данных."
          },
          {
            role: "user",
            content: "Напиши описание для товара «#{product_name}». Категория: #{category.presence || "не указана"}. Не добавляй неподтверждённые характеристики."
          }
        ],
        temperature: 0.7
      }
    )

    description = response.dig("choices", 0, "message", "content")&.strip.presence
    return description if description.present?

    fallback_description(product_name, category)
  rescue Faraday::Error, Faraday::ConnectionFailed, SocketError,
         Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Timeout::Error,
         OpenSSL::SSL::SSLError => e
    Rails.logger.warn("Groq API unavailable; using local fallback description. Error: #{e.class}: #{e.message}")
    fallback_description(product_name, category)
  end

  private

  def fallback_description(product_name, category)
    category_label = category.presence || "универсальная"
    "#{product_name} — удобный товар из категории #{category_label}. Подходит для повседневного использования и помогает сделать быт или рабочее пространство более комфортным."
  end

  def api_key
    ENV["GROQ_API_KEY"] || Rails.application.credentials.dig(:groq, :api_key)
  end
end
