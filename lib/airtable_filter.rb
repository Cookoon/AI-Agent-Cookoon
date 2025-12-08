class AirtableFilter
  def self.filter_chefs(chefs, criteria)
    filtered = chefs.dup
    if criteria[:etoiles].present?
      filtered.select! { |c| c["Reconnaissance"].to_i >= criteria[:etoiles].to_i }
    end

    if criteria[:cuisine].present?
      filtered.select! { |c| c["type_of_cooking"].to_s.downcase.include?(criteria[:cuisine].downcase) }
    end

    if criteria[:budget].present?
      filtered.select! { |c| c["price_dinner_discovery_menu"].to_f <= criteria[:budget].to_f * 1.1 }
    end


    if criteria[:key_words].present?
      filtered.select! do |c|
        c["key_words"].to_s.downcase.split(",").any? { |k| criteria[:key_words].downcase.include?(k.strip) }
      end
    end

    filtered.first(3)
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

    filtered.first(3)
  end
end
