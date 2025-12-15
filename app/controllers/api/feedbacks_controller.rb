class Api::FeedbacksController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token

  # GET /api/feedbacks
  def index
    feedbacks = Feedback.order(created_at: :desc)
    render json: feedbacks
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end

  # POST /api/feedbacks
  def create
    clean_result = extract_names(feedback_params[:result_text])

    feedback = Feedback.new(
      prompt_text: feedback_params[:prompt_text],
      result_text: clean_result,
      rating: feedback_params[:rating],
      creator: feedback_params[:creator]
    )

    if feedback.save
      render json: { success: true, names_stored: clean_result }, status: :created
    else
      render json: { error: feedback.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
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

  private

  def feedback_params
    params.permit(:prompt_text, :result_text, :rating, :creator)
  end

  def extract_names(text)
    text.lines
        .map(&:strip)
        .reject(&:empty?)
        .reject { |l| l =~ /CHEFS|LIEUX|type de cuisine|reconnue|prix|total|€|personnes|style|correspond|arrondissement|dîner|déjeuner|fixe|minimum/i }
        .select { |l| l.split.size <= 6 }
        .uniq
        .join(", ")
  end
end
