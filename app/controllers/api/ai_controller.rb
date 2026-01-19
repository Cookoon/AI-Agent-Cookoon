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


  # Accept ban lists from frontend: prefer ban_chefs/ban_lieux, fallback to legacy keys or nested ai payload
  ban_chefs = params[:ban_chefs] || params['ban_chefs'] || params[:chefs] || params['chefs'] || (params[:ai] && (params[:ai][:ban_chefs] || params[:ai]['ban_chefs'])) || []
  ban_lieux = params[:ban_lieux] || params['ban_lieux'] || params[:lieux] || params['lieux'] || (params[:ai] && (params[:ai][:ban_lieux] || params[:ai]['ban_lieux'])) || []

  ban_list = { chefs: Array(ban_chefs), lieux: Array(ban_lieux) }

    # ------------------ Extraction des critères ------------------
    criteria = build_criteria_from_prompt_auto(user_prompt, chefs_data, lieux_data, params)

  # ------------------ Filtrage ------------------
  # build_criteria_from_prompt_auto returns a hash with :chefs and :lieux
  chefs_criteria = criteria[:chefs] || {}
  lieux_criteria = criteria[:lieux] || {}

  # attach ban lists to criteria so filters can remove banned entries early
  chefs_criteria[:ban_chefs] = ban_list[:chefs]
  lieux_criteria[:ban_lieux] = ban_list[:lieux]

  chefs_filtered = AirtableFilter.filter_chefs(chefs_data, chefs_criteria)
  lieux_filtered = AirtableFilter.filter_lieux(lieux_data, lieux_criteria)

    # ------------------ Supprimer colonnes inutiles ------------------
    chefs_filtered = chefs_filtered.map { |c| c.except("description") }
    lieux_filtered = lieux_filtered.map { |l| l.except("description") }

    # ----------------- Récupération des derniers feedbacks -----------------
    last_feedbacks = Feedback.order(created_at: :desc).map do |f|
      {
        rating: f.rating,
        prompt: f.prompt_text,
        result: f.result_text
      }
    end

    additional_prompt_record = AdditionalPrompt.first
    additional_prompt = additional_prompt_record&.content || ""


    # ------------------ Construction du prompt AI ------------------
    combined_prompt = <<~PROMPT

      Voici les données disponibles :

      #{ban_list.to_json} est la liste des chefs et lieux à exclure

      Chefs :
      #{chefs_filtered.to_json}

      Lieux :
      #{lieux_filtered.to_json}

      Historique récent des feedbacks noté /5 :
      #{last_feedbacks.to_json}

      Nouvelle demande utilisateur :
      "#{user_prompt}"

      Instructions pour la réponse :
      1. Sélectionne les éléments les plus pertinents en fonction de tous les mot clés dans la base de donnée.
      2. Respecte le budget si fourni, il ne doit pas être dépassé.
      3. Ne résume pas le prompt, donne directement la réponse.
      4. Présente les informations clairement et lisiblement.
      5. Les feedbacks précédents doivent t'aider à améliorer la qualité des suggestions mais ne doivent pas être ta source principal pour prendre une décision.
      6. Soit permissif il me faut toujours 3 résultats par catégorie, même si ce n'est pas totalement pertinent.

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
      - Prend en compte en priorité le BUDGET et la CAPACITÉ
      - Le budget chaque combinaison de chef et lieu ne doit pas dépasser le budget total
      - Le price du lieu ne doit pas dépasser les 75% budget total donné
      - Le price_mimimum_spend et les price_fixed est le prix total minimum à payer pour réserver le chef ou le lieu pour la totalité des invités, pas par personnne.
      - Si il n'y a pas de prix par personne, calcule le prix total divisé par le nombre de personnes.
      - Sélectionne 3 chefs et 3 lieux
      - Si il y a moins de 3 résultats, donne uniquement ceux pertinents

      - Le NOM doit être sur une LIGNE SÉPARÉE, seul, sans texte avant ou après
      - La description commence à la ligne suivante
      - Utilise EXACTEMENT les noms tels qu'ils apparaissent dans la base de données
      - Explique brièvement pourquoi chaque chef/lieu est choisi
      - Exprime toi de manière claire et concise sans cité les mots clés dans des ""
      - Indique tous les prix clairement

      Prompt additionnel de l'utilisateur à prendre en compte, si il contredit les instructions précédentes, c'est ce prompt additionnel qui prévaut :
      #{additional_prompt}
    PROMPT

    # ------------------ Estimation des tokens ------------------
    prompt_tokens = estimate_tokens(combined_prompt)
    Rails.logger.info "[AI TOKENS] Prompt tokens estimés : #{prompt_tokens}"

    # ------------------ Appel à Gemini ------------------
    result_text = "Aucun résultat"
    response_tokens = 0

    begin
      result_text = GeminiService.new.generate(combined_prompt, max_tokens: 15000)
      result_text = "Aucun résultat" if result_text.blank?
      result_text.gsub!("*", "")
      result_text.gsub!("#", "")

      response_tokens = estimate_tokens(result_text)

      Rails.logger.info "[AI DEBUG] Réponse Gemini : #{result_text.inspect}"
      Rails.logger.info "[AI TOKENS] Réponse tokens estimés : #{response_tokens}"
      Rails.logger.info "[AI TOKENS] Total tokens estimés : #{prompt_tokens + response_tokens}"
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
  {
    chefs: build_chef_criteria_from_prompt(user_prompt, all_chefs, params),
    lieux: build_lieu_criteria_from_prompt(user_prompt, all_lieux, params)
  }
end

def build_chef_criteria_from_prompt(user_prompt, all_chefs, params = {})
  criteria = {}
  user_prompt_str = user_prompt.to_s.strip

  # Budget
  criteria[:budget] = params[:budget] || user_prompt_str[/\b(\d+)\s*€/i, 1]

  # Nationalité
  # Nationalité: accept explicit param only (heuristic detection removed)
  criteria[:nationality] = params[:nationality]

  # Sexe
  criteria[:sexe] = params[:sexe] || "féminin" if user_prompt_str =~ /\bune\s+chef(fe)?\b/i

  # Étoiles
criteria[:etoile] =
  params[:etoile] ||
  user_prompt_str[/\b(\d+)\s*é?toile?s?\b/i, 1] ||
  (
    user_prompt_str.match?(/\bnon\s+étoilé(e|s)?\b/i) ? 0 :
    user_prompt_str.match?(/\bétoilé(e|s)?\b/i) ? 1 :
    nil
  )


  # Attributs directs
  criteria[:cuisine] = params[:cuisine]
  criteria[:top_chef] = params[:top_chef]
  criteria[:have_restaurant] = params[:have_restaurant]
  criteria[:followers] = params[:followers]

  # Mots-clés chefs
  all_chef_keywords = all_chefs
    .flat_map { |c| c["key_words"].to_s.split(/[\s,;]+/) }
    .uniq

  matched_chef_words = all_chef_keywords.select do |w|
    user_prompt_str.match?(/\b#{Regexp.escape(w)}\b/i)
  end

  criteria[:key_words_chefs] = matched_chef_words.join(", ") unless matched_chef_words.empty?

  criteria
end

def build_lieu_criteria_from_prompt(user_prompt, all_lieux, params = {})
  criteria = {}
  user_prompt_str = user_prompt.to_s.strip

  # Prix
  criteria[:price] = params[:price] || user_prompt_str[/\b(\d+)\s*€/i, 1]

  # Capacité
  criteria[:capacite] = params[:capacite] || user_prompt_str[/\b(\d+)\s*personnes?\b/i, 1]

  # Type de lieu
  criteria[:type_lieu] = params[:type_lieu]

  # Mots-clés lieux
  all_lieu_keywords = all_lieux
    .flat_map { |l| l["key_words"].to_s.split(/[\s,;]+/) }
    .uniq

  matched_lieu_words = all_lieu_keywords.select do |w|
    user_prompt_str.match?(/\b#{Regexp.escape(w)}\b/i)
  end

  criteria[:key_words_lieux] = matched_lieu_words.join(", ") unless matched_lieu_words.empty?

  # Attributs directs
  criteria[:location] = params[:location]
  criteria[:open_kitchen] = params[:open_kitchen]
  criteria[:cheminy] = params[:cheminy]
  criteria[:amenities] = params[:amenities]
  criteria[:outisde_type] = params[:outisde_type]

  criteria
end


  def estimate_tokens(text)
    return 0 if text.blank?
    (text.length / 4.0).ceil
  end
end
