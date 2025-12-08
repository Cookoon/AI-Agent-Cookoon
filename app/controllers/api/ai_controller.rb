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
    # Prompt texte pour l'IA
    user_prompt = params[:prompt].to_s.strip
    Rails.logger.info "[AI DEBUG] Nouveau prompt : #{user_prompt.inspect}"

    # ------------------ Airtable Data ------------------
    chefs_data = Rails.cache.fetch("chefs_data", expires_in: 60.minutes) do
      (AirtableService.new("Chefs").all.fetch("records", []) rescue []).map { |c| c["fields"] }
    end

    lieux_data = Rails.cache.fetch("lieux_data", expires_in: 60.minutes) do
      (AirtableService.new("Lieux").all.fetch("records", []) rescue []).map { |l| l["fields"] }
    end

    # ------------------ Extraction des critères depuis le front ------------------
   criteria = {
  etoiles: params[:etoiles],
  cuisine: params[:cuisine],
  budget: params[:budget],
  capacite: params[:capacite],
  type_lieu: params[:type_lieu],
  key_words: params[:key_words],
  location: params[:location]
}

criteria[:nationality] ||= user_prompt[/chef\s*(japonais|français|italien|thai|indien)/i, 1]


    # ------------------ Filtrage ------------------
    chefs_data = AirtableFilter.filter_chefs(chefs_data, criteria)
    lieux_data = AirtableFilter.filter_lieux(lieux_data, criteria)

    # ------------------ Supprimer colonnes inutiles ------------------
    chefs_data = chefs_data.map { |c| c.except("description", "photo") }
    lieux_data = lieux_data.map { |l| l.except("description", "photo") }

    # ------------------ Construction du prompt AI ------------------
  combined_prompt = <<~PROMPT
      Voici les données disponibles :

      Chefs :
      #{chefs_data.to_json}

      Lieux :
      #{lieux_data.to_json}

      Nouvelle demande utilisateur :
      "#{user_prompt}"

      Instructions pour la réponse :
      1. Sélectionne toujours les éléments les plus pertinents en fonction des mots-clés dans les bases de données.
      2. Respecte le budget si fourni (tolérance +10% max). Fais tous les calculs nécessaires.
      3. Ne résume pas le prompt, donne directement la réponse.
      4. Présente les informations dans un format clair, structuré et lisible pour l’utilisateur.



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

    PROMPT

    # ------------------ Appel à Gemini ------------------
    result_text = "Aucun résultat"
    begin
      result_text = GeminiService.new.generate(combined_prompt, max_tokens: 2000)
      result_text = "Aucun résultat" if result_text.blank?

      # Nettoyage
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
