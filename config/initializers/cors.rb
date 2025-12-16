# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:5173', 'https://ai-agent-cookoon-e863a58f965f.herokuapp.com'
    resource '*',
      headers: :any,
      methods: [:get, :post, :delete, :options],
      credentials: true
  end
end
