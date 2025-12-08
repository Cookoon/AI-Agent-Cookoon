class AirtableCache
  def self.chefs
    @chefs ||= Rails.cache.fetch("chefs_data", expires_in: 12.hours) do
      (AirtableService.new("Chefs").all.fetch("records", []) rescue []).map { |c| c["fields"] }
    end
  end

  def self.lieux
    @lieux ||= Rails.cache.fetch("lieux_data", expires_in: 12.hours) do
      (AirtableService.new("Lieux").all.fetch("records", []) rescue []).map { |l| l["fields"] }
    end
  end

  # force reload
  def self.reload!
    @chefs = nil
    @lieux = nil
  end
end
