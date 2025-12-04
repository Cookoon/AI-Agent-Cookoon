require 'json'
require 'net/http'

class AirtableService
  BASE_URL = "https://api.airtable.com/v0"

  def initialize(table)
    @table = table
    @api_key = ENV["AIRTABLE_API_KEY"]
    @base_id = ENV["AIRTABLE_BASE_ID"]
  end

  def all
    url = "#{BASE_URL}/#{@base_id}/#{@table}"
    puts "URL Airtable: #{url}"

    uri = URI(url)
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{@api_key}"

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    JSON.parse(res.body)
  end
end
