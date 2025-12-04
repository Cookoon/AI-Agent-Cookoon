class Api::AiController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token

  # ------------------- RESET SESSION -------------------
  def reset_session
    session[:user_prompt_session] = []
    render json: { message: "Session vidée" }
  end

  # ------------------- RECOMMEND -------------------
  def recommend
    user_prompt = params[:prompt].to_s.strip
    Rails.logger.info "[AI DEBUG] Nouveau prompt : #{user_prompt.inspect}"

    # Historique session
    session[:user_prompt_session] ||= []
    session[:user_prompt_session] << user_prompt

    # ------------------ Airtable Data ------------------
    chefs_data = Rails.cache.fetch("chefs_data", expires_in: 60.minutes) do
      (AirtableService.new("Chefs").all.fetch("records", []) rescue []).map { |c| c["fields"] }
    end

    lieux_data = Rails.cache.fetch("lieux_data", expires_in: 60.minutes) do
      (AirtableService.new("Lieux").all.fetch("records", []) rescue []).map { |l| l["fields"] }
    end

    # ------------------ Feedback Summary ------------------
    feedback_summary = Feedback.all.map do |fb|
      avg = fb.rating || 0
      prompts = [fb.prompt_text].compact
      results = [fb.result_text].compact
      "Note : #{avg}/5. Prompt : #{prompts.join('; ')}. Résultat : #{results.join('; ')}"
    end.join("\n")

    # ------------------ PROMPT AI ------------------
combined_prompt = <<~PROMPT
  Voici les données disponibles :

  Chefs :
  #{chefs_data.to_json}

  Lieux :
  #{lieux_data.to_json}

  Historique des feedbacks précédents :
  #{feedback_summary.present? ? feedback_summary : "Aucun feedback disponible."}

  Historique des prompts utilisateur :
  #{session[:user_prompt_session].join(" | ")}

  Nouvelle demande utilisateur :
  "#{user_prompt}"

  Instructions pour la réponse :
  1. Sélectionne toujours les éléments les plus pertinents en fonction des mots-clés dans les bases de données.
  2. Mets le nom de chaque chef et lieu en valeur avec un émoji unique. L’émoji doit précéder le nom.
  3. Ne jamais utiliser "**" ou autres formats Markdown.
  4. Respecte le budget si fourni (tolérance +10% max). Fais tous les calculs nécessaires.
  5. Ne résume pas le prompt, donne directement la réponse.
  6. Présente les informations dans un format clair, structuré et lisible pour l’utilisateur.

  CHEFS :
  - Sélectionne 3 chefs les plus pertinents selon la demande.
  - Explique brièvement pourquoi chaque chef est choisi.
  - Indique le prix de chaque chef : Prix: "XX€".
  - Si un nombre de personnes est fourni, indique le prix total : "Prix total YY personnes : XXX€".

  LIEUX :
  - Sélectionne 3 lieux les plus pertinents selon la demande.
  - Explique brièvement pourquoi chaque lieu est choisi.
  - Indique le prix de chaque lieu : Prix: "XX€".
  - Si un nombre de personnes est fourni, indique le prix total pour YY personnes.

  TOP PROPOSITION :
  - Donne 1 seul mix chef + lieu le plus pertinent selon la demande.
  - Indique le prix total.
PROMPT


    # ------------------ CALL GEMINI ------------------
    result_text = "Aucun résultat"

    begin
      result_text = GeminiService.new.generate(combined_prompt, max_tokens: 800)
      result_text = "Aucun résultat" if result_text.blank?

      result_text.gsub!("*", "")
      result_text.gsub!("#", "")

      Rails.logger.info "[AI DEBUG] Réponse Gemini : #{result_text.inspect}"

    rescue => e
      Rails.logger.error "[AI ERROR] Gemini : #{e.message}"
    end

    render json: { resultText: result_text }

  rescue => e
    Rails.logger.error "[AI ERROR] AiController#recommend : #{e.message}"
    render json: { error: e.message, resultText: "Aucun résultat" }, status: :internal_server_error
  end

  # ------------------- FEEDBACK -------------------
  def feedback
    feedback = Feedback.new(
      rating: params[:rating],
      prompt_text: params[:prompt_text],
      result_text: params[:result_text]
    )

    if feedback.save
      render json: { message: "Feedback reçu avec succès", feedback: feedback }, status: :created
    else
      render json: { errors: feedback.errors.full_messages }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Erreur Api::AiController#feedback: #{e.message}"
    render json: { error: "Une erreur est survenue" }, status: :internal_server_error
  end
end
