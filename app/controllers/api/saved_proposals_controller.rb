class Api::SavedProposalsController < ApplicationController


  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token

  def index
    proposals = SavedProposal.order(created_at: :desc)
    render json: proposals
  rescue => e
    Rails.logger.error "[SavedProposals#index] #{e.message}"
    render json: { error: e.message }, status: :internal_server_error
  end

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

  def destroy
    proposal = SavedProposal.find(params[:id])
    proposal.destroy
    render json: { message: "Proposition supprimée" }
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end



def pdf
  proposal = SavedProposal.find(params[:id])
  pdf = Prawn::Document.new

  # --- Police ---

 

  # --- Logo ---
  pdf.image "#{Rails.root}/app/assets/images/Cookoon_Logo_Logo HD sans marge fond blanc (1).jpg",
            width: 120, position: :center
  pdf.move_down 40

  # --- Titre ---
  pdf.text "Proposition de Chefs et Lieux", size: 18, style: :bold, align: :center
  pdf.move_down 40

  # --- Texte ligne par ligne ---
  proposal.proposal_text.to_s.encode('UTF-8').lines.each do |line|
    # Nettoyage du prix : enlever espace invisible avant €, ajouter espace avant parenthèse
    line = line.gsub(/[\s\u00A0]*€/,'€').gsub(/€\(/,'€ (')
    pdf.text line, size: 12, leading: 4
  end

  # --- Envoi du PDF ---
  file_name = "proposition_#{proposal.id}.pdf"
  send_data pdf.render,
            filename: file_name,
            type: "application/pdf",
            disposition: "attachment"
end





end
