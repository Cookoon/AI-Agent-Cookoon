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

    # Accept ban lists from frontend
    ban_chefs = params[:ban_chefs] || params['ban_chefs'] || params[:chefs] || params['chefs'] || (params[:ai] && (params[:ai][:ban_chefs] || params[:ai]['ban_chefs'])) || []
    ban_lieux = params[:ban_lieux] || params['ban_lieux'] || params[:lieux] || params['lieux'] || (params[:ai] && (params[:ai][:ban_lieux] || params[:ai]['ban_lieux'])) || []

    ban_list = { chefs: Array(ban_chefs), lieux: Array(ban_lieux) }

    # ------------------ Extraction des critères ------------------
    criteria = build_criteria_from_prompt_auto(user_prompt, chefs_data, lieux_data, params)

    # ------------------ Filtrage ------------------
    chefs_criteria = criteria[:chefs] || {}
    lieux_criteria = criteria[:lieux] || {}

    chefs_criteria[:ban_chefs] = ban_list[:chefs]
    lieux_criteria[:ban_lieux] = ban_list[:lieux]

    chefs_filtered = AirtableFilter.filter_chefs(chefs_data, chefs_criteria)
    lieux_filtered = AirtableFilter.filter_lieux(lieux_data, lieux_criteria)

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

    additional_prompt_record = AdditionalPrompt.first
    additional_prompt = additional_prompt_record&.content || ""

    # ------------------ Cookoon availability (FIXED VERSION) ------------------
    schedule_date = params[:schedule_date]
    service_type = params[:service_type]

    # FIX: Auto-detect service_type from prompt if not provided
    if service_type.blank? && schedule_date.present?
      prompt_lower = user_prompt.downcase

      if prompt_lower.match?(/déjeuner|lunch/)
        service_type = prompt_lower.include?('cocktail') ? 'lunch_cocktail' : 'lunch'
      elsif prompt_lower.match?(/dîner|diner|soir/)
        service_type = prompt_lower.include?('cocktail') ? 'diner_cocktail' : 'diner'
      else
        # Default to diner if not specified
        service_type = 'diner'
      end

      Rails.logger.info "[AI] service_type auto-detected: #{service_type}"
    end

    # Normalisation ROBUSTE pour matching
    normalize_name = ->(name) do
      return '' if name.nil?
      name.to_s
        .unicode_normalize(:nfkd)  # Décompose les accents
        .gsub(/[^\x00-\x7F]/, '')  # Supprime caractères non-ASCII
        .downcase
        .gsub(/[^a-z0-9\s]/, '')   # Garde seulement lettres, chiffres, espaces
        .gsub(/\s+/, ' ')          # Espaces multiples -> un seul
        .strip
    end

    # Variables pour stocker les résultats
    chefs_with_status = []
    lieux_with_status = []

    if schedule_date.blank? || service_type.blank?
      Rails.logger.warn "[Cookoon] Missing schedule_date (#{schedule_date.inspect}) or service_type (#{service_type.inspect}), skipping availability"
      chefs_with_status = chefs_filtered.map { |c| c.merge('availability' => 'unknown') }
      lieux_with_status = lieux_filtered.map { |l| l.merge('availability' => 'unknown') }
    else
      cookoon_service = CookoonService.new
      cookoon_results = cookoon_service.fetch_schedule_by_date(schedule_date)

      Rails.logger.info "[Cookoon DEBUG] Received keys: #{cookoon_results.keys.inspect}"

      # Isoler les données chefs et lieux
      chefs_results = cookoon_results[:chefsResults] || {}
      lieux_results = cookoon_results[:cookoonsResults] || {}

      # Format de la clé de date: "2026-01-29" avec tirets
      date_key = schedule_date.to_s.gsub('/', '-')
      date_sym = date_key.to_sym
      service_sym = service_type.to_s.to_sym

      Rails.logger.info "[Cookoon] Looking for date: #{date_sym}, service: #{service_sym}"
      Rails.logger.info "[Cookoon] Available date keys: #{chefs_results.keys.inspect}"

      # Extraction des données pour cette date/service
      cookoon_chefs_data = (chefs_results[date_sym] || {})[service_sym] || {}
      cookoon_lieux_data = (lieux_results[date_sym] || {})[service_sym] || {}

      # Récupérer les listes
      available_chefs   = Array(cookoon_chefs_data[:available])
      unavailable_chefs = Array(cookoon_chefs_data[:unavailable])
      available_lieux   = Array(cookoon_lieux_data[:available])
      unavailable_lieux = Array(cookoon_lieux_data[:unavailable])

      Rails.logger.info "[Cookoon] Chefs - Available: #{available_chefs.size}, Unavailable: #{unavailable_chefs.size}"
      Rails.logger.info "[Cookoon] Lieux - Available: #{available_lieux.size}, Unavailable: #{unavailable_lieux.size}"

      # Normaliser les listes Cookoon
      available_chefs_normalized = available_chefs.map(&normalize_name)
      unavailable_chefs_normalized = unavailable_chefs.map(&normalize_name)

      # For lieux, keep both full normalized names and base names (before location suffixes)
      available_lieux_full = available_lieux.map { |n| normalize_name.call(n) }
      available_lieux_basenames = available_lieux.map { |n| normalize_name.call(n.to_s.split(/\s*[-–—]\s*/).first) }
      available_lieux_normalized = (available_lieux_full + available_lieux_basenames).uniq

      # Debug: afficher quelques exemples
      if available_chefs_normalized.any?
        Rails.logger.debug "[Cookoon] Sample available chef normalized: #{available_chefs_normalized.first}"
      end
      if unavailable_chefs_normalized.any?
        Rails.logger.debug "[Cookoon] Sample unavailable chef normalized: #{unavailable_chefs_normalized.first}"
      end

      # CHEFS: Ajout du statut de disponibilité
      chefs_with_status = chefs_filtered.map do |chef|
        chef_name = chef['name'] || chef['id'] || ''
        normalized = normalize_name.call(chef_name)

        availability = if available_chefs_normalized.include?(normalized)
                         'available'
                       else
                         'unavailable'
                       end

        # Debug log pour chefs problématiques
        if availability == 'unknown' && chef_name.present?
          Rails.logger.debug "[Cookoon] Chef '#{chef_name}' → '#{normalized}' NOT FOUND in Cookoon"
        elsif availability == 'unavailable'
          Rails.logger.debug "[Cookoon] Chef '#{chef_name}' → UNAVAILABLE"
        end

        chef.merge('availability' => availability)
      end

      # LIEUX: Ajout du statut de disponibilité (robuste : compare full name, base name, substrings)
      lieux_with_status = lieux_filtered.map do |lieu|
        lieu_name = lieu['name'] || lieu['id'] || ''
        normalized = normalize_name.call(lieu_name)
        base_normalized = normalize_name.call(lieu_name.to_s.split(/\s*[-–—]\s*/).first)

        matched = available_lieux_normalized.any? do |a|
          a == normalized || a == base_normalized || a.include?(normalized) || normalized.include?(a) || a == normalize_name.call(base_normalized)
        end

        availability = matched ? 'available' : 'unavailable'

        unless matched
          Rails.logger.debug "[Cookoon] Lieu '#{lieu_name}' -> normalized='#{normalized}', base='#{base_normalized}' NOT FOUND in available list"
        end

        lieu.merge('availability' => availability)
      end

      # Statistiques finales
      chef_stats = chefs_with_status.group_by { |c| c['availability'] }.transform_values(&:count)
      lieu_stats = lieux_with_status.group_by { |l| l['availability'] }.transform_values(&:count)

      Rails.logger.info "[Cookoon STATS] Chefs: #{chef_stats.inspect}"
      Rails.logger.info "[Cookoon STATS] Lieux: #{lieu_stats.inspect}"
    end

    # ------------------ Construction du prompt AI ------------------
    combined_prompt = <<~PROMPT

    Si aucune date n'est fournie, ou si le service n'est pas spécifié, considère que la disponibilité des chefs et lieux est "unknown".
    📅 Date demandée : #{schedule_date}
    🍽️ Service : #{service_type}

    Chaque chef et chaque lieu possède un statut de disponibilité :
    - "available" : disponible à cette date
    - "unavailable" : non disponible à cette date
    - "unknown" : statut inconnu


    ⚠️ Privilégie TOUJOURS les éléments "available".
    ⚠️ Si un chef ou lieu est marqué "unavailable", tu peux le proposer uniquement si aucun autre choix n'est possible.

    #{ban_list.to_json} est la liste des chefs et lieux à exclure

    Chefs :
    #{chefs_with_status.to_json}

    Lieux :
    #{lieux_with_status.to_json}

    Historique récent des feedbacks noté /5 :
    #{last_feedbacks.to_json}

    Nouvelle demande utilisateur :
    "#{user_prompt}"

    Instructions pour la réponse :
    1. VÉRIFIE LE STATUT "availability" de chaque chef/lieu AVANT de le suggérer
    2. Suggère uniquement les chefs et lieux "available" si possible
    4. Respecte le budget si fourni, il ne doit pas être dépassé
    5. Ne résume pas le prompt, donne directement la réponse
    6. Présente les informations clairement et lisiblement
    7. Les feedbacks précédents doivent t'aider à améliorer la qualité des suggestions
    8. Essaie de fournir 3 résultats par catégorie, mais seulement parmi ceux disponibles

    **FORMAT DE RÉPONSE OBLIGATOIRE** :


    Met les plus pertinents en premier

    CHEFS :

    [Nom du Chef 1]
    [Description]
    Prix : XX€ par personne
    Prix total pour [N] personnes : XXX€
    Disponibilité : available (n'explique pas juste indique le statut)

    LIEUX :
    [Nom du Lieu 1]
    [Description]
    Prix fixe : XXX€
    Prix par personne : XX€
    Prix total pour [N] personnes : XXX€
    Disponibilité : available (n'explique pas juste indique le statut)

    RÈGLES IMPORTANTES :
    - Prend en compte en priorité le BUDGET et la CAPACITÉ
    - Le budget de chaque combinaison chef+lieu ne doit pas dépasser le budget total
    - Le price du lieu ne doit pas dépasser 75% du budget total
    - Le price_minimum_spend et price_fixed sont les prix totaux minimums (pas par personne)
    - Si pas de prix par personne, calcule: prix total ÷ nombre de personnes
    - Sélectionne jusqu'à 3 chefs et 3 lieux DISPONIBLES
    - Si moins de 3 disponibles, donne uniquement ceux qui sont disponibles
    - Le NOM doit être sur une LIGNE SÉPARÉE, seul
    - La description commence à la ligne suivante
    - Utilise EXACTEMENT les noms de la base de données
    - Explique brièvement pourquoi chaque choix
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

  def normalize(value)
    case value
    when Hash
      (value['name'] || value[:name] || '').to_s.strip.downcase
    else
      value.to_s.strip.downcase
    end
  end

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
    criteria[:outside_type] = params[:outside_type]

    criteria
  end

  def estimate_tokens(text)
    return 0 if text.blank?
    (text.length / 4.0).ceil
  end
end
