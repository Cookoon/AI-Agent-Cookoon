# app/services/cookoon_service.rb
require 'net/http'
require 'json'
require 'uri'

class CookoonService
  BASE_URL  = "https://membre.cookoon.club/api/v1"
  LOGIN_URL = "https://membre.cookoon.club/users/sign_in"

  def initialize(email: nil, password: nil)
    @email    = email || ENV['COOKOON_EMAIL']
    @password = password || ENV['COOKOON_PASSWORD']
    @cookies  = {} # Store all cookies with their attributes
    @csrf_token = nil
  end

  # Login with CSRF token extraction
  def login
    return format_cookies if @cookies.any?

    unless @email && @password
      Rails.logger.warn "[CookoonService] no email/password configured; skipping login"
      return nil
    end

    # Step 1: Get the login page to extract CSRF token and initial cookies
    extract_csrf_token

    # Step 2: Attempt login with form data (we know this works from logs)
    login_with_form_data
  end

  private

  # Extract CSRF token from login page and capture ALL cookies
  def extract_csrf_token
    uri  = URI(LOGIN_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.path)
    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      # Extract CSRF token
      if response.body =~ /csrf-token["']\s+content=["']([^"']+)["']/i
        @csrf_token = $1
        Rails.logger.info "[CookoonService] CSRF token extracted: #{@csrf_token[0..10]}..."
      end

      # Store ALL cookies from the response
      store_cookies_from_response(response)
    end
  rescue => e
    Rails.logger.error "[CookoonService] CSRF extraction failed: #{e.message}"
  end

  # Store cookies from Set-Cookie headers (can be multiple)
  def store_cookies_from_response(response)
    # Get all Set-Cookie headers (there can be multiple)
    set_cookies = response.get_fields('set-cookie')
    return unless set_cookies

    set_cookies.each do |cookie_string|
      # Parse cookie: "name=value; path=/; domain=.example.com; ..."
      parts = cookie_string.split(';').map(&:strip)
      next if parts.empty?

      # First part is name=value
      name_value = parts.first.split('=', 2)
      next if name_value.length != 2

      cookie_name = name_value[0]
      cookie_value = name_value[1]

      # Store the full cookie value
      @cookies[cookie_name] = cookie_value
      Rails.logger.debug "[CookoonService] Stored cookie: #{cookie_name}"
    end
  end

  # Format cookies as a single Cookie header string
  def format_cookies
    @cookies.map { |name, value| "#{name}=#{value}" }.join('; ')
  end

  # Form data login
  def login_with_form_data
    uri  = URI(LOGIN_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    headers = {
      'Content-Type' => 'application/x-www-form-urlencoded',
      'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
    }

    # Include existing cookies (from GET request)
    cookie_string = format_cookies
    headers['Cookie'] = cookie_string if cookie_string.present?

    request = Net::HTTP::Post.new(uri.path, headers)

    # Build form data with CSRF token
    form_data = "user[email]=#{CGI.escape(@email)}&user[password]=#{CGI.escape(@password)}"
    form_data += "&authenticity_token=#{CGI.escape(@csrf_token)}" if @csrf_token
    form_data += "&user[remember_me]=1" # Enable remember me

    request.body = form_data

    # CRITICAL: Don't follow redirects automatically, we need to capture cookies
    response = http.request(request)

    Rails.logger.info "[CookoonService] Login response: #{response.code}"

    # Check for success or redirect (302/303 indicates successful login)
    if response.code.to_i.between?(200, 399)
      # Store new cookies from login response
      store_cookies_from_response(response)

      cookie_string = format_cookies
      Rails.logger.info "[CookoonService] Form Login OK, #{@cookies.keys.size} cookies stored"
      Rails.logger.debug "[CookoonService] Cookie names: #{@cookies.keys.join(', ')}"
      return cookie_string
    else
      Rails.logger.error "[CookoonService] Login failed: #{response.code} #{response.body[0..200]}"
      nil
    end
  rescue => e
    Rails.logger.error "[CookoonService] Form login error: #{e.message}"
    nil
  end

  public

  # Récupération du planning avec retry sur échec d'auth
  def fetch_schedule_by_date(date, retry_login: true)
    # Ensure we're logged in
    login if @cookies.empty?

    cookie_string = format_cookies
    unless cookie_string.present?
      Rails.logger.error "[CookoonService] Cannot fetch schedule: no valid session cookies"
      return {}
    end

    date_str =
      if date.is_a?(Date)
        date.strftime("%Y%m%d")
      elsif date.respond_to?(:to_date)
        date.to_date.strftime("%Y%m%d")
      else
        date.to_s.delete("-")
      end

    Rails.logger.info "[CookoonService] fetch schedule for #{date_str}"
    Rails.logger.debug "[CookoonService] Using cookies: #{@cookies.keys.join(', ')}"

    uri  = URI("#{BASE_URL}/schedule?dates[]=#{date_str}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl     = true
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri.request_uri, {
      'Accept' => 'application/json',
      'Cookie' => cookie_string,
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
    })

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body, symbolize_names: true)
      Rails.logger.info "[CookoonService] Schedule fetch successful"
      Rails.logger.debug "[CookoonService DEBUG] cookoon_results: #{result}"
      result
    elsif response.code == '401' && retry_login
      # Session expired, try to re-login once
      Rails.logger.warn "[CookoonService] 401 received, attempting re-login"
      @cookies = {}
      @csrf_token = nil
      login
      fetch_schedule_by_date(date, retry_login: false) # Retry once
    else
      Rails.logger.error "[CookoonService] HTTP #{response.code} - #{response.body.to_s.truncate(400)}"
      {}
    end
  rescue => e
    Rails.logger.error "[CookoonService] error: #{e.message}\n#{e.backtrace[0..5].join("\n")}"
    {}
  end
end
