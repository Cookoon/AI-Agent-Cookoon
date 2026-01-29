# app/controllers/api/sessions_controller.rb
class Api::SessionsController < ApplicationController
  # Permet à l’API de recevoir du JSON sans CSRF
  skip_before_action :verify_authenticity_token

  # POST /api/login
  def create
    # Rails parse automatiquement le JSON envoyé dans le body
    user = User.find_by(name: params[:name])

    if user&.authenticate(params[:password])
      # Enregistre l'user dans la session
      session[:user_id] = user.id

      render json: { name: user.name }, status: :ok
    else
      render json: { error: "Nom ou mot de passe incorrect" }, status: :unauthorized
    end
  end

  # GET /api/me
  def me
    Rails.logger.debug "[API ME] Request cookies: #{request.cookies.inspect}"
    Rails.logger.debug "[API ME] Request header Cookie: #{request.headers['Cookie'].inspect}"
    Rails.logger.debug "[API ME] Session keys: #{session.to_hash.keys.inspect}"

    if session[:user_id]
      user = User.find(session[:user_id])
      render json: { name: user.name }, status: :ok
    else
      render json: { error: "Non connecté" }, status: :unauthorized
    end
  end

  # DELETE /api/logout
  def destroy
    session.delete(:user_id)
    head :no_content
  end
end
