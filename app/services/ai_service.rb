require "openai"

class AiService
  MODEL = "openai/gpt-oss-120b"

  def initialize
    @client = OpenAI::Client.new(
      uri_base: "https://api.groq.com/openai",
      access_token: ENV["GROQ_API_KEY"]
    )
  end

  def ask(prompt, system: "Ты полезный ИИ-помощник. Отвечай ясно и по-русски; технические темы объясняй пошагово.")
    response = @client.chat(
      parameters: {
        model: MODEL,
        messages: [
          { role: "system", content: system },
          { role: "user", content: prompt }
        ],
        temperature: 0.3
      }
    )
    response.dig("choices", 0, "message", "content")
  rescue Faraday::Error => e
    Rails.logger.error("Groq API error: #{e.message}")
    nil
  end
end
