require 'open-uri'

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

  # POST /api/saved_proposals
  def create
    proposal = SavedProposal.new(saved_proposal_params)

    if proposal.save
      render json: proposal, status: :created
    else
      render json: { error: proposal.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "[SavedProposals#create] #{e.message}"
    render json: { error: e.message }, status: :internal_server_error
  end

  # DELETE /api/saved_proposals/:id
  def destroy
    proposal = SavedProposal.find(params[:id])
    proposal.destroy
    render json: { message: "Proposition supprimée" }
  rescue => e
    Rails.logger.error "[SavedProposals#destroy] #{e.message}"
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def saved_proposal_params
    # Ici on whitelist les params reçus du front, y compris :creator
    params.permit(:last_prompt, :proposal_text, :creator)
  end



def pdf
  proposal = SavedProposal.find(params[:id])

  # PDF en format paysage
  pdf = Prawn::Document.new(page_layout: :landscape)

  # === FONT avec bold ===
  nyghtserif_path = "#{Rails.root}/app/assets/fonts/NyghtSerif-Regular.ttf"
  nyghtserif_bold_path = "#{Rails.root}/app/assets/fonts/NyghtSerif-Bold.ttf"
  pdf.font_families.update("NyghtSerif" => { normal: nyghtserif_path, bold: nyghtserif_bold_path })
  pdf.font "NyghtSerif"

  # === PAGE DE GARDE - LOGO CENTRÉ ===

  page_height = pdf.bounds.height
  page_width = pdf.bounds.width
  logo_width = 300
  logo_height = 300

  # Centrer verticalement et horizontalement
  y_position = (page_height + logo_height) / 2
  x_position = (page_width - logo_width) / 2

  pdf.bounding_box([x_position, y_position], width: logo_width, height: logo_height) do
    pdf.image "#{Rails.root}/app/assets/images/Cookoon_Logo_Logo HD sans marge fond blanc (1).jpg",
              width: logo_width, position: :center
  end

  # --- Extraction des données structurées ---
  lines = proposal.proposal_text.to_s.encode('UTF-8').lines

  chef_data = []
  lieu_data = []
  current_section = nil
  current_item = nil

  lines.each_with_index do |line, index|
    line_stripped = line.strip

    # Détection des sections
    if line_stripped =~ /^CHEFS\s*:/i
      current_section = :chefs
      next
    elsif line_stripped =~ /^LIEUX\s*:/i
      current_section = :lieux
      next
    elsif line_stripped.match?(/^(BUDGET|MENU|OPTIONS|DÉTAILS|TOTAL|TARIF|RÉSUMÉ|CONCLUSION)/i)
      current_section = nil
      next
    end

    next if current_section.nil? || line_stripped.empty?

    # Détection d'un nouveau nom (chef ou lieu)
    if line_stripped.match?(/^[A-ZÀÂÄÉÈÊËÏÎÔÙÛÜŸÇ]/) &&
       line_stripped.length > 2 &&
       line_stripped.length < 50 &&
       !line_stripped.include?(':') &&
       !line_stripped.match?(/^(Prix|Ce\s|Clément\soffre|Situé|Thibaut\sest)/i)

      # Sauvegarder l'item précédent s'il existe
      if current_item
        if current_section == :chefs
          chef_data << current_item
        elsif current_section == :lieux
          lieu_data << current_item
        end
      end

      # Créer un nouvel item
      current_item = {
        name: line_stripped,
        description: []
      }
    elsif current_item
      # Ajouter à la description
      current_item[:description] << line_stripped
    end
  end

  # Sauvegarder le dernier item
  if current_item
    if current_section == :chefs
      chef_data << current_item
    elsif current_section == :lieux
      lieu_data << current_item
    end
  end

  Rails.logger.info "=" * 80
  Rails.logger.info "Chefs extraits: #{chef_data.size}"
  chef_data.each { |c| Rails.logger.info "  - #{c[:name]}" }
  Rails.logger.info "Lieux extraits: #{lieu_data.size}"
  lieu_data.each { |l| Rails.logger.info "  - #{l[:name]}" }
  Rails.logger.info "=" * 80

  # --- Charger les images ---
  chef_data.each do |chef|
    image_data = fetch_airtable_image("Chefs", chef[:name])
    chef[:image] = image_data if image_data
    Rails.logger.info "Chef '#{chef[:name]}': image #{image_data ? 'trouvée' : 'manquante'}"
  end

  lieu_data.each do |lieu|
    image_data = fetch_airtable_image("Lieux", lieu[:name])
    lieu[:image] = image_data if image_data
    Rails.logger.info "Lieu '#{lieu[:name]}': image #{image_data ? 'trouvée' : 'manquante'}"
  end

  # === GÉNÉRER LES PAGES CHEFS ===
  chef_data.each do |chef|
    pdf.start_new_page

    # Titre de la section
    pdf.text "CHEF", size: 16, style: :bold, color: "666666"
    pdf.move_down 10

    # Nom du chef centré en haut
    pdf.text chef[:name], size: 22, style: :bold, align: :center
    pdf.move_down 30

    # Image à gauche et texte à droite
    if chef[:image]
      begin
        y_position = pdf.cursor

        # Image à gauche
        pdf.bounding_box([0, y_position], width: 350, height: 400) do
          pdf.image StringIO.new(chef[:image]), fit: [350, 400]
        end

        # Texte à droite
        if chef[:description].any?
          description_text = chef[:description].join("\n")
          pdf.bounding_box([370, y_position], width: 370, height: 400) do
            pdf.text description_text, size: 11, leading: 5, align: :left
          end
        end
      rescue => e
        Rails.logger.error "Erreur image chef '#{chef[:name]}': #{e.message}"
      end
    elsif chef[:description].any?
      # Si pas d'image, afficher juste le texte
      description_text = chef[:description].join("\n")
      pdf.text description_text, size: 11, leading: 5, align: :left
    end
  end

  # === GÉNÉRER LES PAGES LIEUX ===
  lieu_data.each_with_index do |lieu, index|
    pdf.start_new_page

    # Titre de la section
    pdf.text "LIEU", size: 16, style: :bold, color: "666666"
    pdf.move_down 10

    # Nom du lieu centré en haut
    pdf.text lieu[:name], size: 22, style: :bold, align: :center
    pdf.move_down 30

    # Image à gauche et texte à droite
    if lieu[:image]
      begin
        y_position = pdf.cursor

        # Image à gauche
        pdf.bounding_box([0, y_position], width: 350, height: 400) do
          pdf.image StringIO.new(lieu[:image]), fit: [350, 400]
        end

        # Texte à droite
        if lieu[:description].any?
          description_text = lieu[:description].join("\n")
          pdf.bounding_box([370, y_position], width: 370, height: 400) do
            pdf.text description_text, size: 11, leading: 5, align: :left
          end
        end
      rescue => e
        Rails.logger.error "Erreur image lieu '#{lieu[:name]}': #{e.message}"
      end
    elsif lieu[:description].any?
      # Si pas d'image, afficher juste le texte
      description_text = lieu[:description].join("\n")
      pdf.text description_text, size: 11, leading: 5, align: :left
    end
  end

  send_data pdf.render,
            filename: "proposition_#{proposal.id}.pdf",
            type: "application/pdf",
            disposition: "attachment"
end

# ---------------- Airtable ----------------
def fetch_airtable_image(table, name)
  return nil if name.blank?

  airtable_key = ENV['AIRTABLE_API_KEY']
  base_id      = ENV['AIRTABLE_BASE_ID']

  clean_name = name.strip

  # Essayer d'abord avec 'Nom', puis 'Name', puis 'name'
  ['Nom', 'Name', 'name'].each do |field_name|
    # Utiliser le field_name courant pour la formule et recherche insensible à la casse
    filter = URI.encode_www_form_component("LOWER({#{field_name}})=\"#{clean_name.downcase}\"")
    url = "https://api.airtable.com/v0/#{base_id}/#{table}?filterByFormula=#{filter}"

    Rails.logger.info "  🔍 Recherche avec {#{field_name}}: '#{clean_name}'"

    begin
      response = URI.open(url, "Authorization" => "Bearer #{airtable_key}")
      data = JSON.parse(response.read)

      Rails.logger.info "  📊 Records trouvés: #{data['records']&.size || 0}"

      next unless data['records']&.any?

      record = data['records'].first
      Rails.logger.info "  📝 Champs disponibles: #{record['fields'].keys.inspect}"

      # Récupérer toutes les images du champ 'photo'
      images = record.dig("fields", "photo") || []
      if images.any?
        images.each do |img|
          Rails.logger.info "  📷 Image trouvée: #{img['url']}"
        end
        # Télécharger la première image (ou tu peux changer selon ton besoin)
        image_data = URI.open(images.first['url']).read
        Rails.logger.info "  ✅ Image téléchargée: #{image_data.bytesize} bytes"
        return image_data
      else
        Rails.logger.warn "  ⚠️ Pas de champ 'photo' ou images vides dans le record"
      end
    rescue OpenURI::HTTPError => e
      Rails.logger.debug "  Tentative avec {#{field_name}} échouée: #{e.message}"
    rescue => e
      Rails.logger.error "  ❌ Erreur inattendue: #{e.class} - #{e.message}"
      Rails.logger.error "  #{e.backtrace.first(3).join("\n  ")}"
    end
  end

  Rails.logger.warn "  ❌ Aucune image trouvée pour '#{clean_name}' avec aucun des champs testés"
  nil
end

end
