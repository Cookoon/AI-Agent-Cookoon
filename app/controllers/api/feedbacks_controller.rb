class Api::FeedbacksController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token

  # POST /api/feedbacks
  def create
  feedback = Feedback.new(
    prompt_text: params[:prompt_text],
    result_text: params[:result_text],
    rating: params[:rating]
  )

  if feedback.save
    render json: { success: true, feedback: feedback }, status: :created
  else
    render json: { error: feedback.errors.full_messages.join(", ") }, status: :unprocessable_entity
  end
end


  # GET /api/feedbacks
  def index
    feedbacks = Feedback.order(created_at: :desc)
    render json: feedbacks
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end

  # DELETE /api/feedbacks/:id
  def destroy
    feedback = Feedback.find_by(id: params[:id])
    if feedback
      feedback.destroy
      render json: { message: "Feedback supprimé" }
    else
      render json: { error: "Feedback non trouvé" }, status: :not_found
    end
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end
end
