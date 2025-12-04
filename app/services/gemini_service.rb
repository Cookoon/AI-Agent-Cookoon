require "net/http"
require "uri"
require "json"

class GeminiService
  # dans GeminiService
PRIMARY_MODEL = "gemini-2.0-flash"



  BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

  def initialize
    @api_key = ENV["GEMINI_API_KEY"]
    raise "GEMINI_API_KEY absente dans .env" unless @api_key
  end

  # prompt : texte à envoyer
  # max_tokens : limite de tokens
  def generate(prompt, max_tokens: 600)
    # 1️⃣ essai avec modèle principal
    result = request_model(PRIMARY_MODEL, prompt, max_tokens)

    # 2️⃣ fallback si vide
    if result.nil? || result.strip.empty? || result == "Aucune réponse"
      Rails.logger.warn "[GeminiService] Primary model empty, trying fallback model..."
      result = request_model(FALLBACK_MODEL, prompt, max_tokens)
    end

    result || "Aucune réponse"
  rescue => e
    Rails.logger.error "[GeminiService ERROR] #{e.message}"
    "Erreur lors de l'appel à Gemini"
  end

  private

  def request_model(model, prompt, max_tokens)
    uri = URI("#{BASE_URL}/#{model}:generateContent?key=#{@api_key}")

    body = {
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { maxOutputTokens: max_tokens }
    }.to_json

    headers = { "Content-Type" => "application/json" }

    response = Net::HTTP.post(uri, body, headers)

    Rails.logger.debug "[GeminiService DEBUG] Response raw: #{response.body}"

    json = JSON.parse(response.body) rescue {}

    # récupération du texte selon structure standard
    text = json.dig("candidates", 0, "content", "parts", 0, "text")

    # fallback si la structure change
    if text.nil?
      # certaines réponses mettent directement 'candidates[0].content' ou 'output_text'
      text = json.dig("candidates", 0, "content", 0, "text") ||
             json["output_text"] ||
             json.to_s
    end

    text
  end
end
