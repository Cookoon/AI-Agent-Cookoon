Rails.application.config.session_store :cookie_store,
  key: "_app_session",
  same_site: :none,
  secure: Rails.env.production?,
  httponly: true
