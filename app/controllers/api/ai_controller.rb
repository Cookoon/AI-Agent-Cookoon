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
    chefs_data = Rails.cache.fetch("chefs_data", expires_in: 180.minutes) do
      (AirtableService.new("Chefs").all.fetch("records", []) rescue []).map { |c| c["fields"] }
    end

    lieux_data = Rails.cache.fetch("lieux_data", expires_in: 180.minutes) do
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
    criteria[:sexe] ||= "féminin" if user_prompt =~ /\bune\s+chef(fe)?\b/i

    # ------------------ Filtrage ------------------
    chefs_data = AirtableFilter.filter_chefs(chefs_data, criteria)
    lieux_data = AirtableFilter.filter_lieux(lieux_data, criteria)

    # ------------------ Supprimer colonnes inutiles ------------------
    chefs_data = chefs_data.map { |c| c.except("description") }
    lieux_data = lieux_data.map { |l| l.except("description") }

    # ----------------- Récupération des derniers feedbacks -----------------
    last_feedbacks = Feedback.order(created_at: :desc).limit(10).map do |f|
      {
        rating: f.rating,
        prompt: f.prompt_text,
        result: f.result_text
      }
    end

    # ------------------ Construction du prompt AI ------------------
    combined_prompt = <<~PROMPT
      Voici les données disponibles :

      Chefs :
      #{chefs_data.to_json}

      Lieux :
      #{lieux_data.to_json}

      Historique récent des feedbacks (10 derniers) noté /5 , 5/5 était une recommendation parfaite, 1/5 une mauvaise recommendation :
      #{last_feedbacks.to_json}

      Nouvelle demande utilisateur :
      "#{user_prompt}"

      Instructions pour la réponse :
      1. Sélectionne toujours les éléments les plus pertinents en fonction des bases de données.
      2. Respecte le budget si fourni (tolérance +10% max). Fais tous les calculs nécessaires.
      3. Ne résume pas le prompt, donne directement la réponse.
      4. Présente les informations dans un format clair, structuré et lisible pour l'utilisateur.

      **FORMAT DE RÉPONSE OBLIGATOIRE** :

      CHEFS :

      [Nom du Chef 1]
      [Description et justification du choix]
      Prix : XX€ par personne
      Prix total pour [N] personnes : XXX€

      [Nom du Chef 2]
      [Description et justification du choix]
      Prix : XX€ par personne
      Prix total pour [N] personnes : XXX€

      [Nom du Chef 3]
      [Description et justification du choix]
      Prix : XX€ par personne
      Prix total pour [N] personnes : XXX€

      LIEUX :

      [Nom du Lieu 1]
      [Description et justification du choix]
      Prix fixe : XXX€
      Prix par personne : XX€
      Prix total pour [N] personnes : XXX€

      [Nom du Lieu 2]
      [Description et justification du choix]
      Prix fixe : XXX€
      Prix par personne : XX€
      Prix total pour [N] personnes : XXX€

      [Nom du Lieu 3]
      [Description et justification du choix]
      Prix fixe : XXX€
      Prix par personne : XX€
      Prix total pour [N] personnes : XXX€

      RÈGLES IMPORTANTES :
      - Le NOM doit être sur une LIGNE SÉPARÉE, seul, sans texte avant ou après
      - La description commence à la ligne suivante
      - Sélectionne exactement 3 chefs et 3 lieux
      - Utilise EXACTEMENT les noms tels qu'ils apparaissent dans la base de données (respecte majuscules, accents, espaces)
      - Explique brièvement pourquoi chaque chef/lieu est choisi en parlant directement au client
      - Ne mentionne pas "mot-clé" ou "pourquoi il est choisi"
      - Indique tous les prix clairement

      Ne propose pas de Suggestion combinée Chef + Lieu.
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
