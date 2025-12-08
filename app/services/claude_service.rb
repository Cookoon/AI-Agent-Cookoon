class ClaudeService
  def initialize
    @api_key = ENV["CLAUDE_API_KEY"]
    @url = URI("https://api.anthropic.com/v1/messages")
  end

  def generate(prompt, max_tokens: 200)  # ← ici
    req = Net::HTTP::Post.new(@url)
    req["x-api-key"] = @api_key
    req["anthropic-version"] = "2023-06-01"
    req["content-type"] = "application/json"

    req.body = {
      model: "claude-sonnet-4-20250514",
      messages: [{ role: "user", content: prompt }],
      max_tokens: max_tokens
    }.to_json

    res = Net::HTTP.start(@url.host, @url.port, use_ssl: true) do |http|
      http.request(req)
    end

    body = JSON.parse(res.body)

    if body["completion"].present?
      body["completion"]
    elsif body["content"].is_a?(Array) && body["content"].first["text"]
      body["content"].first["text"]
    else
      Rails.logger.warn "[ClaudeService] Réponse inattendue : #{body.inspect}"
      "Aucun résultat"
    end
  rescue => e
    Rails.logger.error "[ClaudeService] Erreur : #{e.message}"
    "Aucun résultat"
  end
end
