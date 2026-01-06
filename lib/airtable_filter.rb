class AirtableFilter
  # ----------------- CHEFS -----------------
  def self.filter_chefs(chefs, criteria)
    filtered = chefs.dup


    filtered.select! { |c| c["nationality"].to_s.include?(criteria[:nationality].to_s) } if criteria[:nationality].present?
    filtered.select! { |c| c["sexe"].to_s.include?(criteria[:sexe].to_s) } if criteria[:sexe].present?

    if criteria[:etoiles].present?
      etoiles_req = criteria[:etoiles].to_i
      filtered.select! { |c| c["reconnaissance"].to_s.scan(/\d+/).first.to_i >= etoiles_req }
    end

    filtered.select! { |c| c["type_of_cooking"].to_s.include?(criteria[:cuisine].to_s) } if criteria[:cuisine].present?

     filtered.select! { |c| c["top_chef"].to_s.include?(criteria[:top_chef].to_s) } if criteria[:top_chef].present?

    if criteria[:key_words_chefs].present?
      searched_words = criteria[:key_words_chefs].split(/[\s,;]+/)
      filtered.select! do |c|
        chef_keywords = c["key_words"].to_s.split(/[\s,;]+/)
        chef_keywords.any? do |k|
          searched_words.include?(k)
        end
      end
    end

    if criteria[:budget].present?
      columns = ["price_dinner_discovery_menu","price_dinner_cocktail_menu","price_minimum_spend","price_minimum_spend_diner"]
      filtered.select! { |c| columns.any? { |col| c[col].to_f <= criteria[:budget].to_f * 1.1 } }
    end

    filtered.select! { |c| c["have_restaurant"].to_s.include?(criteria[:have_restaurant].to_s) } if criteria[:have_restaurant].present?

    filtered.select! { |c| c["followers"].to_s.include?(criteria[:followers].to_s) } if criteria[:followers].present?

    filtered
  end

  # ----------------- LIEUX -----------------
  def self.filter_lieux(lieux, criteria)
    filtered = lieux.dup
        if criteria[:price].present?
      columns = ["price_fixed Lunch","price_by_guest lunch","price_fixed_dinner","price_by_guest diner"]
      filtered.select! { |c| columns.any? { |col| c[col].to_f <= criteria[:budget].to_f * 1.1 } }
    end

    filtered.select! { |l| l["decor_style"].to_s.include?(criteria[:type_lieu].to_s) } if criteria[:type_lieu].present?
    filtered.select! { |l| l["price_fixed_lunch"].to_f <= criteria[:budget].to_f * 1.1 } if criteria[:budget].present?

    if criteria[:capacite].present?
      columns = ["outside_capacity_sit","outside_capacity_standing","outside_with_rent","inside_capacity_sit","inside_capacity_standing","inside_with_rent"]
      filtered.select! { |l| columns.any? { |col| l[col].to_i >= criteria[:capacite].to_i } }
    end

    if criteria[:key_words_lieux].present?
      searched_words = criteria[:key_words_lieux].split(/[\s,;]+/)
      filtered.select! do |l|
        lieu_keywords = l["key_words"].to_s.split(/[\s,;]+/)
        lieu_keywords.any? do |k|
          searched_words.include?(k)
        end
      end
    end
    filtered.select! { |l| l["location"].to_s.include?(criteria[:location].to_s) } if criteria[:location].present?

     filtered.select! { |l| l["open_kitchen"].to_s.include?(criteria[:open_kitchen].to_s) } if criteria[:open_kitchen].present?

      filtered.select! { |l| l["outisde_type"].to_s.include?(criteria[:outisde_type].to_s) } if criteria[:outisde_type].present?

       filtered.select! { |l| l["cheminy"].to_s.include?(criteria[:cheminy].to_s) } if criteria[:cheminy].present?

        filtered.select! { |l| l["amenities"].to_s.include?(criteria[:amenities].to_s) } if criteria[:amenities].present?


    filtered
  end
end
