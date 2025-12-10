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

    # === FONT avec bold ===
    nyghtserif_path = "#{Rails.root}/app/assets/fonts/NyghtSerif-Regular.ttf"
    nyghtserif_bold_path = "#{Rails.root}/app/assets/fonts/NyghtSerif-Bold.ttf"
    pdf.font_families.update("NyghtSerif" => { normal: nyghtserif_path, bold: nyghtserif_bold_path })
    pdf.font "NyghtSerif"

    # === LOGO ===
    pdf.image "#{Rails.root}/app/assets/images/Cookoon_Logo_Logo HD sans marge fond blanc (1).jpg",
              width: 120, position: :center
    pdf.move_down 40
    pdf.text "Proposition de Chefs et Lieux", size: 18, align: :center
    pdf.move_down 40

    # --- Extraction noms de CHEFS et LIEUX ---
    lines = proposal.proposal_text.to_s.encode('UTF-8').lines

    Rails.logger.info "=" * 80
    Rails.logger.info "DÉBUT EXTRACTION DES NOMS"
    Rails.logger.info "=" * 80

    chef_names = []
    lieu_names = []
    current_section = nil

    lines.each_with_index do |line, index|
      line_stripped = line.strip

      Rails.logger.info "[Ligne #{index}] '#{line_stripped}' | Section: #{current_section}"

      if line_stripped =~ /^CHEFS\s*:/i
        current_section = :chefs
        Rails.logger.info "  ➡️ Début section CHEFS"
        next
      elsif line_stripped =~ /^LIEUX\s*:/i
        current_section = :lieux
        Rails.logger.info "  ➡️ Début section LIEUX"
        next
      end

      # Si on est dans une section
      if current_section && !line_stripped.empty?
        # Arrêter si on rencontre une nouvelle section majeure
        if line_stripped.match?(/^(BUDGET|MENU|OPTIONS|DÉTAILS|TOTAL|TARIF|RÉSUMÉ|CONCLUSION)/i)
          Rails.logger.info "  ❌ Fin de section"
          current_section = nil
          next
        end

        # Ignorer les lignes qui commencent par "Prix", "Ce", etc.
        if line_stripped.match?(/^(Prix|Ce\s|Clément\soffre|Situé|Thibaut\sest)/i)
          Rails.logger.info "  ⏭️ Ligne de description ignorée"
          next
        end

        # Détecter un nom : commence par une majuscule, longueur raisonnable
        if line_stripped.match?(/^[A-ZÀÂÄÉÈÊËÏÎÔÙÛÜŸÇ]/) &&
           line_stripped.length > 2 &&
           line_stripped.length < 50 &&
           !line_stripped.include?(':')

          # Prendre toute la ligne comme nom (au cas où il y a prénom + nom)
          name = line_stripped.strip

          if current_section == :chefs && chef_names.size < 3
            chef_names << name
            Rails.logger.info "  ✅ 👨‍🍳 Chef #{chef_names.size}: '#{name}'"
          elsif current_section == :lieux && lieu_names.size < 3
            lieu_names << name
            Rails.logger.info "  ✅ 📍 Lieu #{lieu_names.size}: '#{name}'"
          end
        else
          Rails.logger.info "  ⚠️ Pas un nom (pattern non respecté)"
        end
      end
    end



    # --- Pré-charger les images depuis Airtable ---
    chef_images = {}
    lieu_images = {}

    chef_names.each_with_index do |name, idx|

      image_data = fetch_airtable_image("Chefs", name)
      if image_data
        chef_images[name] = image_data
        Rails.logger.info "  ✅ Image trouvée (#{image_data.bytesize} bytes)"
      else
        Rails.logger.warn "  ⚠️ Pas d'image trouvée pour '#{name}'"
      end
    end

    lieu_names.each_with_index do |name, idx|
      Rails.logger.info "Chargement image lieu #{idx + 1}/#{lieu_names.size}: '#{name}'"
      image_data = fetch_airtable_image("Lieux", name)
      if image_data
        lieu_images[name] = image_data
        Rails.logger.info "  ✅ Image trouvée (#{image_data.bytesize} bytes)"
      else
        Rails.logger.warn "  ⚠️ Pas d'image trouvée pour '#{name}'"
      end
    end

    Rails.logger.info "=" * 80
    Rails.logger.info "Images chargées - Chefs: #{chef_images.size}/#{chef_names.size}, Lieux: #{lieu_images.size}/#{lieu_names.size}"
    Rails.logger.info "Chef images keys: #{chef_images.keys.inspect}"
    Rails.logger.info "Lieu images keys: #{lieu_images.keys.inspect}"
    Rails.logger.info "=" * 80

    # --- PDF ligne par ligne ---
    lines.each do |line|
      line = line.gsub(/[\s\u00A0]*€/,'€').gsub(/€\(/,'€ (')
      line_text = line.strip

      if line_text =~ /^CHEFS\s*:/i
        pdf.move_down 10
        pdf.text "CHEFS", size: 12, style: :bold
        pdf.move_down 5
        next
      elsif line_text =~ /^LIEUX\s*:/i
        pdf.move_down 10
        pdf.text "LIEUX", size: 12, style: :bold
        pdf.move_down 5
        next
      end

      # Afficher la ligne
      pdf.text line, size: 12, leading: 4

      # Vérifier si cette ligne contient un nom de chef
      chef_names.each do |chef_name|
        if line_text == chef_name && chef_images[chef_name]
          pdf.move_down 5
          begin
            pdf.image StringIO.new(chef_images[chef_name]), width: 180
            pdf.move_down 10
            Rails.logger.info "📷 Image PDF ajoutée pour chef: '#{chef_name}'"
          rescue => e
            Rails.logger.error "❌ Erreur ajout image chef '#{chef_name}': #{e.message}"
          end
          break
        end
      end

      # Vérifier si cette ligne contient un nom de lieu
      lieu_names.each do |lieu_name|
        if line_text == lieu_name && lieu_images[lieu_name]
          pdf.move_down 5
          begin
            pdf.image StringIO.new(lieu_images[lieu_name]), width: 180
            pdf.move_down 10
            Rails.logger.info "📷 Image PDF ajoutée pour lieu: '#{lieu_name}'"
          rescue => e
            Rails.logger.error "❌ Erreur ajout image lieu '#{lieu_name}': #{e.message}"
          end
          break
        end
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
    filter = URI.encode_www_form_component("{#{field_name}}='#{clean_name}'")
    url = "https://api.airtable.com/v0/#{base_id}/#{table}?filterByFormula=#{filter}"

    Rails.logger.info "  🔍 Recherche avec {#{field_name}}: '#{clean_name}'"

    begin
      response = URI.open(url, "Authorization" => "Bearer #{airtable_key}")
      data = JSON.parse(response.read)

      Rails.logger.info "  📊 Records trouvés: #{data['records']&.size || 0}"

      if data['records']&.any?
        record = data['records'].first
        Rails.logger.info "  📝 Champs disponibles: #{record['fields'].keys.inspect}"

        image_url = record.dig("fields", "photo", 0, "url")

        if image_url
          image_data = URI.open(image_url).read
          Rails.logger.info "  ✅ Image téléchargée: #{image_data.bytesize} bytes"
          return image_data
        else
          Rails.logger.warn "  ⚠️ Pas de champ 'photo' dans le record"
        end
      end
    rescue => e
      Rails.logger.debug "  Tentative avec {#{field_name}} échouée: #{e.message}"
    end
  end

  Rails.logger.warn "  ❌ Aucune image trouvée pour '#{clean_name}' avec aucun des champs testés"
  nil
rescue => e
  Rails.logger.error "  ❌ Erreur: #{e.class} - #{e.message}"
  Rails.logger.error "  #{e.backtrace.first(3).join("\n  ")}"
  nil
end
end
