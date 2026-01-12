class AirtableFilter


  CHEF_PERCENTAGE_OF_BUDGET = 0.28
  LIEU_PERCENTAGE_OF_BUDGET = 0.20

  CHEF_PRICE_COLUMNS = %w[
    price_dinner_discovery_menu
    price_lunch_discovery_menu
    price_dinner_cocktail_menu
    price_minimum_spend
    price_minimum_spend_diner
  ]

  LIEU_PRICE_COLUMNS = %w[
    price_fixed_lunch
    price_by_guest_lunch
    price_fixed_dinner
    price_by_guest_dinner
  ]

  LIEU_CAPACITY_COLUMNS = %w[
    outside_capacity_sit
    outside_capacity_standing
    outside_with_rent
    inside_capacity_sit
    inside_capacity_standing
    inside_with_rent
  ]

  # ----------------- HELPERS -----------------
  def self.normalize(str)
    # remove accents for safer matching if I18n is available
    s = str.to_s
    if defined?(I18n) && I18n.respond_to?(:transliterate)
      s = I18n.transliterate(s)
    else
      # basic ASCII fallback: remove common accents
      s = s.tr('ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÙÚÛÜùúûüÇçÑñ', 'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuCcNn')
    end
    s.downcase.strip
  end

  def self.keyword_score(item_keywords, searched_words)
    (item_keywords & searched_words).size
  end


  # ======================= CHEFS ===========================

def self.filter_chefs(chefs, criteria)
  filtered = chefs.dup
  Rails.logger.info("[AirtableFilter][CHEFS] initial count=#{filtered.size}") if defined?(Rails)

  # ----------------- BAN LIST -----------------
  if criteria[:ban_chefs].present?
    bans = Array(criteria[:ban_chefs]).map { |b| normalize(b) }
    before_ban = filtered.size
    filtered.reject! do |c|
      name = normalize(c['name'] || c['id'])
      bans.any? { |b| name.match?(/\b#{Regexp.escape(b)}\b/) }
    end
    Rails.logger.info("[AirtableFilter][CHEFS][BAN] removed=#{before_ban - filtered.size} remaining=#{filtered.size}") if defined?(Rails)
  end

  # ----------------- FILTRE BUDGET -----------------
  budget_value = (criteria[:budget] || criteria[:price]).to_f
  if budget_value.positive?
    max_chef_budget = budget_value * CHEF_PERCENTAGE_OF_BUDGET
    Rails.logger.info("[AirtableFilter][CHEFS][BUDGET] budget_value=#{budget_value} max_chef_budget=#{max_chef_budget}") if defined?(Rails)

    before_count = filtered.size
    candidates_before = filtered.dup
    filtered.select! do |c|
      CHEF_PRICE_COLUMNS.any? { |col| c[col].to_f.positive? && c[col].to_f <= max_chef_budget }
    end

    # If strict budget removes all candidates, try a relaxed budget threshold (50% more)
    if filtered.empty?
      relaxed_budget = max_chef_budget * 1.5
      Rails.logger.warn("[AirtableFilter][CHEFS][BUDGET] strict filter removed all candidates, trying relaxed_budget=#{relaxed_budget}") if defined?(Rails)
      relaxed = candidates_before.select do |c|
        CHEF_PRICE_COLUMNS.any? { |col| c[col].to_f.positive? && c[col].to_f <= relaxed_budget }
      end

      if relaxed.any?
        filtered = relaxed
        Rails.logger.info("[AirtableFilter][CHEFS][BUDGET] relaxed match count=#{filtered.size}") if defined?(Rails)
      else
        # If still none, restore original list but log a warning — budget filter effectively skipped
        filtered = candidates_before
        Rails.logger.warn("[AirtableFilter][CHEFS][BUDGET] no chefs match budget even after relaxation; skipping budget filter") if defined?(Rails)
      end
    end

    Rails.logger.info("[AirtableFilter][CHEFS][BUDGET] before=#{before_count} after=#{filtered.size}") if defined?(Rails)
  end

  # ----------------- SCORING -----------------
  Rails.logger.info("[AirtableFilter][CHEFS][SCORING] start scoring #{filtered.size} chefs") if defined?(Rails)

  filtered = filtered.map do |c|
    score = 0
    debug_reasons = []

    if criteria[:key_words_chefs].present?
      searched = criteria[:key_words_chefs].downcase.split(/[\s,;]+/)
      keywords = c["key_words"].to_s.downcase.split(/[\s,;]+/)
      kw_score = keyword_score(keywords, searched) * 2
      score += kw_score
      debug_reasons << "keywords(+#{kw_score})" if kw_score > 0
    end

      if criteria[:etoile].present?
  recon = normalize(c["reconnaissance"])
  if criteria[:etoile].to_i == 0
    score += 1 if recon.match?(/\bnon[\s-]*étoilé(e|s)?\b/i)
  else
    score += 1 if recon.match?(/\b#{criteria[:etoile]}\s*étoile?s?\b/i)
  end
end


    if criteria[:cuisine].present?
      if normalize(c["type_of_cooking"]).include?(normalize(criteria[:cuisine]))
        score += 1
        debug_reasons << "cuisine(+1)"
      end
    end

    if criteria[:top_chef].present?
      if normalize(c["top_chef"]) == normalize(criteria[:top_chef])
        score += 1
        debug_reasons << "top_chef(+1)"
      end
    end

    if criteria[:have_restaurant].present?
      if normalize(c["have_restaurant"]) == normalize(criteria[:have_restaurant])
        score += 1
        debug_reasons << "have_restaurant(+1)"
      end
    end

    if criteria[:followers].present?
      if c["followers"].to_i >= criteria[:followers].to_i
        score += 1
        debug_reasons << "followers(+1)"
      end
    end

    Rails.logger.info(
      "[AirtableFilter][CHEFS][SCORE] #{c['name'] || c['id']} score=#{score} reasons=#{debug_reasons.join(', ')} " \
      "reconnaissance=#{c['reconnaissance'].inspect} type_of_cooking=#{c['type_of_cooking'].inspect}"
    ) if defined?(Rails)

    c.merge("_score" => score)
  end

  # ----------------- FILTRE SCORE > 0 -----------------
  before_score_filter = filtered.size
  scored = filtered.select { |c| c["_score"] > 0 }

  Rails.logger.info(
    "[AirtableFilter][CHEFS][SCORE FILTER] before=#{before_score_filter} after=#{scored.size}"
  ) if defined?(Rails)

  filtered = scored.any? ? scored : filtered

  # ----------------- TRI + LIMIT -----------------
  sorted = filtered.sort_by { |c| -c["_score"] }
  Rails.logger.info(
    "[AirtableFilter][CHEFS][FINAL] sorted_count=#{sorted.size} returning=#{[sorted.size].min}"
  ) if defined?(Rails)

  sorted
end


  # ======================= LIEUX ===========================

  def self.filter_lieux(lieux, criteria)
    filtered = lieux.dup

    # ----------------- BAN LIST -----------------
    if criteria[:ban_lieux].present?
      bans = Array(criteria[:ban_lieux]).map { |b| normalize(b) }
      before_ban = filtered.size
      filtered.reject! do |l|
        name = normalize(l['name'] || l['id'])
        bans.any? { |b| name.match?(/\b#{Regexp.escape(b)}\b/) }
      end
      Rails.logger.info("[AirtableFilter][LIEUX][BAN] removed=#{before_ban - filtered.size} remaining=#{filtered.size}") if defined?(Rails)
    end

    # ----------------- FILTRE BUDGET STRICT -----------------
    # accept either :budget or :price and either :capacite or :capacity
    lieu_budget = (criteria[:price] || criteria[:budget]).to_f
    lieu_capacity = (criteria[:capacite] || criteria[:capacity]).to_i

    if lieu_budget.positive? && lieu_capacity.positive?
      max_total_budget = lieu_budget * lieu_capacity * LIEU_PERCENTAGE_OF_BUDGET
      Rails.logger.info("[AirtableFilter] Lieu budget=#{lieu_budget} capacity=#{lieu_capacity} max_total_budget=#{max_total_budget}") if defined?(Rails)
      before_count = filtered.size
      candidates_before = filtered.dup
      filtered.select! do |l|
        LIEU_PRICE_COLUMNS.any? do |col|
          price = l[col].to_f
          next false if price <= 0
          # convertir prix par invité en total si nécessaire
          price *= lieu_capacity if col.to_s.downcase.include?("guest") || col.to_s.downcase.include?("by_guest")
          price <= max_total_budget
        end
      end

      # Relax if none matched
      if filtered.empty?
        relaxed_total = max_total_budget * 1.5
        Rails.logger.warn("[AirtableFilter] Lieux strict budget removed all candidates, trying relaxed_total=#{relaxed_total}") if defined?(Rails)
        relaxed = candidates_before.select do |l|
          LIEU_PRICE_COLUMNS.any? do |col|
            price = l[col].to_f
            next false if price <= 0
            price *= lieu_capacity if col.to_s.downcase.include?("guest") || col.to_s.downcase.include?("by_guest")
            price <= relaxed_total
          end
        end

        if relaxed.any?
          filtered = relaxed
          Rails.logger.info("[AirtableFilter] Lieux relaxed match count=#{filtered.size}") if defined?(Rails)
        else
          filtered = candidates_before
          Rails.logger.warn("[AirtableFilter] Lieux: no matches after relaxation; skipping budget filter") if defined?(Rails)
        end
      end

      after_count = filtered.size
      Rails.logger.info("[AirtableFilter] Lieux filtered by budget: before=#{before_count} after=#{after_count}") if defined?(Rails)
    end

    # Calcul du score
    filtered = filtered.map do |l|
      score = 0

      # Capacité
      if criteria[:capacite].present?
        cap = criteria[:capacite].to_i
        score += 1 if LIEU_CAPACITY_COLUMNS.any? { |col| l[col].to_i >= cap }
      end

      # Keywords
      if criteria[:key_words_lieux].present?
        searched = criteria[:key_words_lieux].downcase.split(/[\s,;]+/)
        keywords = l["key_words"].to_s.downcase.split(/[\s,;]+/)
        score += keyword_score(keywords, searched) * 2
      end

      # Type / decor
      if criteria[:type_lieu].present?
        decor_values = case l["decor_style"]
                       when Array then l["decor_style"]
                       when String then [l["decor_style"]]
                       else []
                       end
        score += 3 if decor_values.any? { |d| normalize(d).include?(normalize(criteria[:type_lieu])) }
      end

      # Location
      score += 1 if criteria[:location].present? && normalize(l["location"]).include?(normalize(criteria[:location]))

      # Open kitchen, cheminy, outside_type, amenities
      %i[open_kitchen cheminy outside_type amenities].each do |key|
        score += 1 if criteria[key].present? && normalize(l[key.to_s]) == normalize(criteria[key])
      end

      l.merge("_score" => score)
    end

    # Retirer ceux avec score 0, fallback si vide
    scored = filtered.select { |c| c["_score"] > 0 }
    filtered = scored.any? ? scored : filtered

    # Trier par score décroissant et limiter
    filtered.sort_by { |l| -l["_score"] }

  end
end
