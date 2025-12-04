# app/controllers/api/ai_feedback_controller.rb
class Api::AiFeedbacksController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token

  # POST /api/ai/feedback
  def create
    # Normalize feedback type: allow 'global' from frontend and map to a valid enum
    incoming_type = params[:type].to_s
    normalized_type = if incoming_type == 'global'
      'chefs' # map legacy/global feedbacks to 'chefs' by default
    else
      incoming_type
    end

    unless Feedback.feedback_types.keys.include?(normalized_type)
      render json: { error: "Type de feedback invalide : #{incoming_type}" }, status: :unprocessable_entity and return
    end

    feedback = Feedback.new(
      feedback_type: normalized_type,
      prompt_text: params[:prompt_text],
      result_text: params[:result_text],
      rating: params[:rating]
    )

    if feedback.save
      render json: { success: true }
    else
      render json: { error: feedback.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  # GET /api/ai/feedback_summary
  def summary
    summaries = Feedback.group(:feedback_type).pluck(:feedback_type).map do |type|
      feedbacks = Feedback.where(feedback_type: type)
      next if feedbacks.empty?

      average_rating = feedbacks.average(:rating).round(1)
      top_prompts = feedbacks.order(rating: :desc).limit(3).pluck(:prompt_text)
      top_results = feedbacks.order(rating: :desc).limit(3).pluck(:result_text)

      {
        type: type,
        average_rating: average_rating,
        summary_text: "Note moyenne : #{average_rating}/5. Prompts : #{top_prompts.join('; ')}. Résultats : #{top_results.join('; ')}"
      }
    end.compact

    render json: summaries
  end

    def index
    feedbacks = Feedback.order(created_at: :desc)
    render json: feedbacks
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def destroy
    feedback = Feedback.find(params[:id])
    feedback.destroy
    render json: { message: "Feedback supprimé" }
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end


end
