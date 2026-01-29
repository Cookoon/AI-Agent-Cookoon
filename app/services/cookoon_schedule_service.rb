# app/services/cookoon_schedule_service.rb
class CookoonScheduleService
  def initialize
    @cookoon_api = CookoonService.new
  end

  # items : Array de Hashs {id:, name:, ...}
  # type : :chefs ou :lieux
  # date : String ou Date
  def fetch_available(date, items, type:)
    available_items = items.select do |item|
      item_id = item[:id] || item['id']
      @cookoon_api.available?(item_id, type: type, date: date)
    end

    Rails.logger.info "[CookoonScheduleService] #{type} disponibles pour #{date} : #{available_items.size}"
    available_items
  end
end
