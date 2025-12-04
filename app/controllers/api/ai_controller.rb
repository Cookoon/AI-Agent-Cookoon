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
    feedback_summary = Feedback.group(:feedback_type).pluck(:feedback_type).map do |type_value|
      feedbacks = Feedback.where(feedback_type: type_value)
      next if feedbacks.empty?
      avg = feedbacks.average(:rating)&.round(1) || 0
      prompts = feedbacks.order(rating: :desc).limit(3).pluck(:prompt_text)
      results = feedbacks.order(rating: :desc).limit(3).pluck(:result_text)
      "#{type_value.upcase} - Note moyenne : #{avg}/5. Prompts : #{prompts.join('; ')}. Résultats : #{results.join('; ')}"
    end.compact.join("\n")

    # ------------------ PROMPT AI ------------------
    combined_prompt = <<~PROMPT
      Voici les données des chefs :
      #{chefs_data.to_json}

      Voici les données des lieux :
      #{lieux_data.to_json}

      Résumé des feedbacks précédents :
      #{feedback_summary.present? ? feedback_summary : "Aucun feedback disponible."}

      Historique prompts : #{session[:user_prompt_session].join(" | ")}

      Nouvelle demande utilisateur : "#{user_prompt}"

      Choisis toujours les éléments les plus pertinents.
      Mets le nom de chaque chef en valeur avec un émoji différent.
      Ne jamais utiliser "**" dans ta réponse.

      Si un budget est fourni, respecte-le (tolérance +10% max).
      Fais les calculs nécessaires.

      Ne résume pas mon prompt dans ta réponse.

      CHEFS
      Sélectionne 3 chefs les plus pertinents selon la demande et indique pourquoi tu les à choisis.
      Indique leur prix : Prix: "XX€".
      Si nombre de personnes présent -> Prix total YY personnes : XXX€

      LIEUX :
      Sélectionne 3 lieux les plus pertinents selon la demande et indique pourquoi tu les à choisis.
      Indique leur prix : Prix: "XX€".
      Si nombre de personnes présent -> Prix total pour YY personnes

      TOP PROPOSITIONS
      Donne moi 1 seul mix chefs + lieux le plus pertinent selon ma demande.
      Indique le prix total.
    PROMPT

    # ------------------ CALL GEMINI ------------------
    result_text = "Aucun résultat"

    begin
      result_text = GeminiService.new.generate(combined_prompt, max_tokens: 800)
      result_text = "Aucun résultat" if result_text.blank?

      result_text.gsub!("*", "")

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
      feedback_type: params[:type],
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
