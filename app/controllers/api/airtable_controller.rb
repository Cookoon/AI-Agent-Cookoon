class Api::AirtableController < ApplicationController
  def resources
    table_names = (ENV['AIRTABLE_TABLE_NAMES'] || "").split(",")
    result = {}

    table_names.each do |table|
      table.strip!
      next if table.empty?

      begin
        records = AirtableService.new(table).all
        result[table.downcase.to_sym] = records["records"] || []
      rescue => e
        puts "Erreur Airtable pour #{table}: #{e.message}"
        result[table.downcase.to_sym] = []
      end
    end

    render json: result
  end
end
