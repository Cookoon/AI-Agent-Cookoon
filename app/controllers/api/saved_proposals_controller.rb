# app/controllers/api/saved_proposals_controller.rb
class Api::SavedProposalsController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token

  # GET /api/saved_proposals
  def index
    proposals = SavedProposal.order(created_at: :desc)
    render json: proposals
  end

  # POST /api/saved_proposals
  def create
    proposal = SavedProposal.new(
      last_prompt: params[:last_prompt],
      proposal_text: params[:proposal_text]
    )

    if proposal.save
      render json: proposal
    else
      render json: { error: proposal.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  # DELETE /api/saved_proposals/:id
  def destroy
    proposal = SavedProposal.find(params[:id])
    proposal.destroy
    render json: { message: "Proposition supprimée" }
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end
end
