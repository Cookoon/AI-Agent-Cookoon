require "net/http"
require "uri"
require "json"

class GeminiService
  PRIMARY_MODEL = "gemini-2.5-flash-lite"
  FALLBACK_MODEL = "gemini-2.5-flash"

  BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

  def initialize
    @api_key = ENV["GEMINI_API_KEY"]
    raise "GEMINI_API_KEY absente dans .env" unless @api_key
  end


  def generate(prompt, max_tokens: 1000)
    # 1️⃣ essai modèle principal
    result = request_model(PRIMARY_MODEL, prompt, max_tokens)

    # 2️⃣ fallback si vide
    if result.nil? || result.strip.empty? || result == "Aucune réponse"
      Rails.logger.warn "[GeminiService] Primary model vide, essai fallback..."
      result = request_model(FALLBACK_MODEL, prompt, max_tokens)
    end

    result.presence || "Aucune réponse générée."
  rescue => e
    Rails.logger.error "[GeminiService ERROR] #{e.message}"
    "Erreur lors de l'appel à Gemini"
  end

  private

  # Requête à Gemini pour générer le texte
  def request_model(model, prompt, max_tokens)
    uri = URI("#{BASE_URL}/#{model}:generateContent?key=#{@api_key}")

    body = {
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { maxOutputTokens: max_tokens }
    }.to_json

    headers = { "Content-Type" => "application/json" }

    response = Net::HTTP.post(uri, body, headers)
    Rails.logger.debug "[GeminiService DEBUG] RAW response: #{response.body}"

    json = JSON.parse(response.body) rescue {}

    # Extraction robuste du texte
    text = json.dig("candidates", 0, "content", "parts", 0, "text") ||
           json.dig("candidates", 0, "content", "text") ||
           json["output_text"] ||
           json.to_s

    text
  rescue => e
    Rails.logger.error "[GeminiService ERROR] request_model: #{e.message}"
    nil
  end
end
