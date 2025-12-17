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

    # ------------------ Airtable Data ------------------
  chefs_data = Rails.cache.fetch("chefs_data") do
  (AirtableService.new("Chefs").all.fetch("records", []) rescue []).map { |c| c["fields"] }
end

lieux_data = Rails.cache.fetch("lieux_data") do
  (AirtableService.new("Lieux").all.fetch("records", []) rescue []).map { |l| l["fields"] }
end


    # ------------------ Extraction des critères ------------------
    criteria = build_criteria_from_prompt_auto(user_prompt, chefs_data, lieux_data, params)

    # ------------------ Filtrage ------------------
    chefs_filtered = AirtableFilter.filter_chefs(chefs_data, criteria)
    lieux_filtered = AirtableFilter.filter_lieux(lieux_data, criteria)

    # ------------------ Supprimer colonnes inutiles ------------------
    chefs_filtered = chefs_filtered.map { |c| c.except("description") }
    lieux_filtered = lieux_filtered.map { |l| l.except("description") }

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
      #{chefs_filtered.to_json}

      Lieux :
      #{lieux_filtered.to_json}

      Historique récent des feedbacks (10 derniers) noté /5 :
      #{last_feedbacks.to_json}

      Nouvelle demande utilisateur :
      "#{user_prompt}"

      Instructions pour la réponse :
      1. Sélectionne les éléments les plus pertinents en fonction de tous les mot clés dans la base de donnée.
      2. Respecte le budget si fourni (+10% tolérance max).
      3. Ne résume pas le prompt, donne directement la réponse.
      4. Présente les informations clairement et lisiblement.
      5. Les feedbacks précédents doivent t'aider à améliorer la qualité des suggestions mais ne doivent pas être ta source principal pour prendre une décision.

      **FORMAT DE RÉPONSE OBLIGATOIRE** :

      Met les plus pertinents en premier
      CHEFS :
      [Nom du Chef 1]
      [Description]
      Prix : XX€ par personne
      Prix total pour [N] personnes : XXX€

      LIEUX :
      [Nom du Lieu 1]
      [Description]
      Prix fixe : XXX€
      Prix par personne : XX€
      Prix total pour [N] personnes : XXX€

      RÈGLES IMPORTANTES :
      - Le NOM doit être sur une LIGNE SÉPARÉE, seul, sans texte avant ou après
      - La description commence à la ligne suivante
      - Sélectionne exactement 3 chefs et 3 lieux
      - Si il y a moins de 3 résultats, donne uniquement ceux pertinents
      - Utilise EXACTEMENT les noms tels qu'ils apparaissent dans la base de données
      - Explique brièvement pourquoi chaque chef/lieu est choisi
      - Exprime toi de manière claire et concise sans cité les mots clés dans des ""
      - Indique tous les prix clairement
    PROMPT

    # ------------------ Appel à Gemini ------------------
    result_text = "Aucun résultat"
    begin
      result_text = GeminiService.new.generate(combined_prompt, max_tokens: 2000)
      result_text = "Aucun résultat" if result_text.blank?
      result_text.gsub!("*", "")
      result_text.gsub!("#", "")
      Rails.logger.info "[AI DEBUG] Réponse Gemini : #{result_text.inspect}"
    rescue => e
      Rails.logger.error "[AI ERROR] Gemini : #{e.message}"
    end

    render json: { resultText: result_text }

  rescue => e
    Rails.logger.error "[AI ERROR] AiController#recommend : #{e.message}\n#{e.backtrace.join("\n")}"
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

  private

def build_criteria_from_prompt_auto(user_prompt, all_chefs, all_lieux, params = {})
  criteria = {}
  user_prompt_str = user_prompt.to_s.strip

  # ---------------- CHEFS ----------------

  all_nationalities = %w[japonais francais italien mexicain portugais colombien]
  criteria[:nationality] = params[:nationality] || all_nationalities.find do |nat|
    user_prompt_str.match?(/#{Regexp.escape(nat)}/i)
  end


  criteria[:sexe] = params[:sexe] || "féminin" if user_prompt_str =~ /\bune\s+chef(fe)?\b/i

  criteria[:etoiles] = params[:etoiles] || user_prompt_str[/\b(\d+)\s*etoiles?\b/i, 1]

  criteria[:cuisine] = params[:cuisine]

  criteria[:budget] = params[:budget] || user_prompt_str[/\b(\d+)\s*€/i, 1]

  criteria[:followers] = params[:followers]

  # Mots-clés CHEFS : scan tous les mots clés, OR match, insensible à la casse
  all_chef_keywords = all_chefs.flat_map { |c| c["key_words"].to_s.split(/[\s,;]+/) }.uniq
  matched_chef_words = all_chef_keywords.select do |w|
    user_prompt_str.match?(/\b#{Regexp.escape(w)}\b/i)
  end
  criteria[:key_words_chefs] = matched_chef_words.join(", ") unless matched_chef_words.empty?

  # ---------------- LIEUX ----------------

  criteria[:capacite] = params[:capacite] || user_prompt_str[/\b(\d+)\s*personnes?\b/i, 1]


  criteria[:type_lieu] = params[:type_lieu]

  # Mots-clés LIEUX : scan tous les mots clés, OR match, insensible à la casse
  all_lieu_keywords = all_lieux.flat_map { |l| l["key_words"].to_s.split(/[\s,;]+/) }.uniq
  matched_lieu_words = all_lieu_keywords.select do |w|
    user_prompt_str.match?(/\b#{Regexp.escape(w)}\b/i)
  end
  criteria[:key_words_lieux] = matched_lieu_words.join(", ") unless matched_lieu_words.empty?

  # Localisation
  criteria[:location] = params[:location]

  criteria
end


end
