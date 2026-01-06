class AirtableFilter
  MAX_RESULTS = 15          # nombre max envoyé au LLM
  BUDGET_TOLERANCE = 1.1

  CHEF_PRICE_COLUMNS = %w[
    price_dinner_discovery_menu
    price_dinner_cocktail_menu
    price_minimum_spend
    price_minimum_spend_diner
  ]

  LIEU_PRICE_COLUMNS = %w[
    price_fixed Lunch
    price_by_guest lunch
    price_fixed_dinner
    price_by_guest diner
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
    str.to_s.downcase.strip
  end

  def self.keyword_score(item_keywords, searched_words)
    (item_keywords & searched_words).size
  end

  # =========================================================
  # ======================= CHEFS ===========================
  # =========================================================
  def self.filter_chefs(chefs, criteria, limit: true)
    filtered = chefs.dup # ⚠️ DB complète

    # -------- Filtres durs --------
    if criteria[:nationality].present?
      filtered.select! { |c| normalize(c["nationality"]) == normalize(criteria[:nationality]) }
    end

    if criteria[:sexe].present?
      filtered.select! { |c| normalize(c["sexe"]) == normalize(criteria[:sexe]) }
    end

    if criteria[:etoiles].present?
      etoiles = criteria[:etoiles].to_i
      filtered.select! do |c|
        c["reconnaissance"].to_s.scan(/\d+/).first.to_i >= etoiles
      end
    end

    if criteria[:cuisine].present?
      filtered.select! do |c|
        normalize(c["type_of_cooking"]).include?(normalize(criteria[:cuisine]))
      end
    end

    if criteria[:top_chef].present?
      filtered.select! { |c| normalize(c["top_chef"]) == normalize(criteria[:top_chef]) }
    end

    if criteria[:have_restaurant].present?
      filtered.select! { |c| normalize(c["have_restaurant"]) == normalize(criteria[:have_restaurant]) }
    end

    if criteria[:followers].present?
      filtered.select! { |c| c["followers"].to_i >= criteria[:followers].to_i }
    end

    if criteria[:budget].present?
      budget = criteria[:budget].to_f * BUDGET_TOLERANCE
      filtered.select! do |c|
        CHEF_PRICE_COLUMNS.any? { |col| c[col].to_f.positive? && c[col].to_f <= budget }
      end
    end

    # -------- Scoring keywords --------
    if criteria[:key_words_chefs].present?
      searched = criteria[:key_words_chefs].downcase.split(/[\s,;]+/)

      filtered = filtered.map do |c|
        keywords = c["key_words"].to_s.downcase.split(/[\s,;]+/)
        score = keyword_score(keywords, searched)
        c.merge("_score" => score)
      end

      filtered.select! { |c| c["_score"] > 0 }
      filtered.sort_by! { |c| -c["_score"] }
    end

    limit ? filtered.first(MAX_RESULTS) : filtered
  end

  # =========================================================
  # ======================= LIEUX ===========================
  # =========================================================
  def self.filter_lieux(lieux, criteria, limit: true)
    filtered = lieux.dup # ⚠️ DB complète

    # -------- Filtres durs --------
    if criteria[:price].present?
      price = criteria[:price].to_f * BUDGET_TOLERANCE
      filtered.select! do |l|
        LIEU_PRICE_COLUMNS.any? { |col| l[col].to_f.positive? && l[col].to_f <= price }
      end
    end

    if criteria[:type_lieu].present?
      filtered.select! do |l|
        normalize(l["decor_style"]).include?(normalize(criteria[:type_lieu]))
      end
    end

    if criteria[:capacite].present?
      cap = criteria[:capacite].to_i
      filtered.select! do |l|
        LIEU_CAPACITY_COLUMNS.any? { |col| l[col].to_i >= cap }
      end
    end

    if criteria[:location].present?
      filtered.select! do |l|
        normalize(l["location"]).include?(normalize(criteria[:location]))
      end
    end

    if criteria[:open_kitchen].present?
      filtered.select! { |l| normalize(l["open_kitchen"]) == normalize(criteria[:open_kitchen]) }
    end

    if criteria[:outisde_type].present?
      filtered.select! { |l| normalize(l["outisde_type"]) == normalize(criteria[:outisde_type]) }
    end

    if criteria[:cheminy].present?
      filtered.select! { |l| normalize(l["cheminy"]) == normalize(criteria[:cheminy]) }
    end

    if criteria[:amenities].present?
      filtered.select! do |l|
        normalize(l["amenities"]).include?(normalize(criteria[:amenities]))
      end
    end

    # -------- Scoring keywords --------
    if criteria[:key_words_lieux].present?
      searched = criteria[:key_words_lieux].downcase.split(/[\s,;]+/)

      filtered = filtered.map do |l|
        keywords = l["key_words"].to_s.downcase.split(/[\s,;]+/)
        score = keyword_score(keywords, searched)
        l.merge("_score" => score)
      end

      filtered.select! { |l| l["_score"] > 0 }
      filtered.sort_by! { |l| -l["_score"] }
    end

    limit ? filtered.first(MAX_RESULTS) : filtered
  end
end
