require "openai"

class AiDescriptionService
  MODEL = "openai/gpt-oss-20b"

  def initialize
    @client = OpenAI::Client.new(
      uri_base: "https://api.groq.com/openai",
      access_token: api_key
    )
  end

  def generate_description(product_name)
    response = @client.chat(
      parameters: {
        model: MODEL,
        messages: [
          {
            role: "system",
            content: "Ты помощник для интернет-магазина. Пиши краткие привлекательные описания товаров на русском языке, 2–3 предложения."
          },
          {
            role: "user",
            content: "Опиши товар: #{product_name}"
          }
        ],
        temperature: 0.7
      }
    )
    response.dig("choices", 0, "message", "content")
    rescue Faraday::Error => e          # ← ВОТ СЮДА
    Rails.logger.error("Groq API error: #{e.message}")
    nil
  end

  private

  def api_key
    ENV["GROQ_API_KEY"] || Rails.application.credentials.dig(:groq, :api_key)
  end
end
