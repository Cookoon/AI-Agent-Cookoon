class AirtableFilter
  def self.filter_chefs(chefs, criteria)
    filtered = chefs.dup

if criteria[:nationality].present?
  filtered.select! do |c|
    match = c["nationality"].to_s.parameterize.downcase.include?(criteria[:nationality].to_s.parameterize.downcase)
    puts "[FILTER DEBUG] Chef: #{c['name']}, Nationality: #{c['nationality']}, Match: #{match}"
    match
  end
end


    if criteria[:cuisine].present?
      filtered.select! { |c| c["type_of_cooking"].to_s.downcase.include?(criteria[:cuisine].downcase) }
    end

    if criteria[:budget].present?
      columns = ["price_dinner_discovery_menu", "price_dinner_cocktail_menu", "price_minimum_spend", "price_minimum_spend_diner"]
      filtered.select! { |c| columns.any? { |col| c[col].to_f <= criteria[:budget].to_f * 1.1 } }
    end

    if criteria[:etoiles].present?
      etoiles_req = criteria[:etoiles].to_i
      filtered.select! do |c|
        stars = c["Reconnaissance"].to_s.scan(/\d+/).first.to_i
        stars >= etoiles_req
      end
    end



    if criteria[:key_words].present?
      filtered.select! do |c|
        c["key_words"].to_s.downcase.split(",").any? { |k| criteria[:key_words].downcase.include?(k.strip) }
      end
    end

    filtered.first(10)
  end

  def self.filter_lieux(lieux, criteria)
    filtered = lieux.dup

    if criteria[:type_lieu].present?
      filtered.select! { |l| l["decor_style"].to_s.downcase.include?(criteria[:type_lieu].downcase) }
    end

    if criteria[:budget].present?
      filtered.select! { |l| l["price_fixed_lunch"].to_f <= criteria[:budget].to_f * 1.1 }
    end

    if criteria[:capacite].present?
      columns = ["outside_capacity_sit", "outside_capacity_standing", "outside_with_rent", "inside_capacity_sit", "inside_capacity_standing", "inside_with_rent"]
      filtered.select! { |l| columns.any? { |col| l[col].to_i >= criteria[:capacite].to_i } }
    end

    if criteria[:key_words].present?
      filtered.select! do |l|
        l["key_words"].to_s.downcase.split(",").any? { |k| criteria[:key_words].downcase.include?(k.strip) }
      end
    end

    if criteria[:location].present?
      filtered.select! { |l| l["location"].to_s.downcase.include?(criteria[:location].downcase) }
    end

    filtered.first(10)
  end
end
