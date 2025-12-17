class Api::AdditionalPromptsController < ApplicationController
  # Permet à l’API de recevoir du JSON sans CSRF
  skip_before_action :verify_authenticity_token

  # GET /api/additional_prompt
  def show
    prompt = AdditionalPrompt.first_or_create!(content: "")
    render json: serialize_prompt(prompt)
  end

  # PUT /api/additional_prompt
  def update
    prompt = AdditionalPrompt.first_or_create!(content: "")
    prompt.update!(
      content: params[:content],
      updated_by: current_user
    )
    render json: serialize_prompt(prompt)
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def serialize_prompt(prompt)
    {
      content: prompt.content,
      updated_at: prompt.updated_at,
      updated_by: prompt.updated_by&.name
    }
  end
end
