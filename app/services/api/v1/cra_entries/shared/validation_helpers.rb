# frozen_string_literal: true

module Api
  module V1
    module CraEntries
      module Shared
        # Centralized validation helpers for CRA Entries
        # Implements P1.2.8 - Centralisation des validations selon Recovery Action Plan
        #
        # Cette centrale les validations communes entre CreateService et UpdateService
        # pour éviter la duplication de code et respecter la séparation:
        # - Format/présence: Service
        # - Cohérence métier: Domaine
        # - JSON/params: Controller
        # - Statut HTTP: Controller
        #
        module ValidationHelpers
          # === VALIDATIONS FORMAT/PRÉSENCE (dans les Services) ===

          # Validation du format de date
          # @param date_param [Object] Paramètre de date à valider
          # @param field_name [Symbol] Nom du champ pour les erreurs
          # @return [Date] Objet Date parsé
          # @raise [CraErrors::InvalidPayloadError] Si la date est invalide
          def validate_date_format(date_param, field_name = :date)
            return nil if date_param.blank?

            date = Date.parse(date_param.to_s)
            unless date.is_a?(Date)
              raise CraErrors::InvalidPayloadError.new(
                'Date must be a valid date',
                field: field_name
              )
            end
            date
          rescue ArgumentError
            raise CraErrors::InvalidPayloadError.new(
              'Date must be in valid format (YYYY-MM-DD)',
              field: field_name
            )
          end

          # Validation de la quantité
          # @param quantity_param [Object] Paramètre de quantité à valider
          # @param field_name [Symbol] Nom du champ pour les erreurs
          # @return [BigDecimal] Quantité validée
          # @raise [CraErrors::InvalidPayloadError] Si la quantité est invalide
          def validate_quantity(quantity_param, field_name = :quantity)
            return nil if quantity_param.blank?

            quantity = quantity_param.to_d
            if quantity.negative?
              raise CraErrors::InvalidPayloadError.new(
                'Quantity cannot be negative',
                field: field_name
              )
            end
            if quantity > 1000 # Limite mise à jour selon les corrections récentes
              raise CraErrors::InvalidPayloadError.new(
                'Quantity cannot exceed 1000 days',
                field: field_name
              )
            end
            quantity
          end

          # Validation du prix unitaire
          # @param unit_price_param [Object] Paramètre de prix unitaire à valider
          # @param field_name [Symbol] Nom du champ pour les erreurs
          # @return [Integer] Prix unitaire validé en centimes
          # @raise [CraErrors::InvalidPayloadError] Si le prix unitaire est invalide
          def validate_unit_price(unit_price_param, field_name = :unit_price)
            return nil if unit_price_param.blank?

            unit_price = unit_price_param.to_i
            if unit_price.negative?
              raise CraErrors::InvalidPayloadError.new(
                'Unit price cannot be negative',
                field: field_name
              )
            end
            if unit_price > 1_000_000_000 # 10M EUR en centimes
              raise CraErrors::InvalidPayloadError.new(
                'Unit price cannot exceed 10,000,000 EUR',
                field: field_name
              )
            end
            unit_price
          end

          # Validation de la description
          # @param description_param [Object] Paramètre de description à valider
          # @param field_name [Symbol] Nom du champ pour les erreurs
          # @return [String] Description validée
          # @raise [CraErrors::InvalidPayloadError] Si la description est invalide
          def validate_description(description_param, field_name = :description)
            return nil if description_param.blank?

            description = description_param.to_s.strip
            if description.length > 500
              raise CraErrors::InvalidPayloadError.new(
                'Description cannot exceed 500 characters',
                field: field_name
              )
            end
            description
          end

          # === VALIDATIONS PERMISSIONS ===

          # Vérification de l'accès au CRA
          # @param cra [Cra] CRA à vérifier
          # @param current_user [User] Utilisateur courant
          # @raise [CraErrors::UnauthorizedError] Si l'utilisateur n'a pas accès
          def check_cra_access!(cra, current_user)
            accessible_cras = Cra.accessible_to(current_user)
            unless accessible_cras.exists?(id: cra.id)
              raise CraErrors::UnauthorizedError, 'User does not have access to this CRA'
            end
          end

          # Vérification si le CRA peut être modifié
          # @param cra [Cra] CRA à vérifier
          # @return [ApplicationResult, nil] nil si valide, Result.fail si invalide
          def check_cra_modifiable!(cra)
            return Result.fail(
              error: :conflict,
              status: :conflict,
              message: 'CRA is locked and cannot be modified'
            ) if cra.locked?

            return Result.fail(
              error: :conflict,
              status: :conflict,
              message: 'Cannot modify entries in submitted CRAs'
            ) if cra.submitted?

            nil # CRA is modifiable
          end

          # Vérification de l'accès à la mission
          # @param mission_id [String] ID de la mission
          # @param current_user [User] Utilisateur courant
          # @raise [CraErrors::MissionNotFoundError] Si la mission n'existe pas ou n'est pas accessible
          def check_mission_access!(mission_id, current_user)
            return if mission_id.blank?

            mission = Mission.find_by(id: mission_id)
            raise CraErrors::MissionNotFoundError, 'Mission does not exist' unless mission.present?

            # Vérification de l'accès via les relations de company
            user_has_access = UserCompany.joins(:company)
                                        .joins('INNER JOIN mission_companies ON mission_companies.company_id = user_companies.company_id')
                                        .where(user_companies: { user_id: current_user.id, role: %w[independent client] })
                                        .where(mission_companies: { mission_id: mission_id })
                                        .exists?

            unless user_has_access
              raise CraErrors::MissionNotFoundError, 'User does not have access to the specified mission'
            end
          end

          # === VALIDATIONS MÉTIER ===

          # Vérification de duplication d'entrée
          # @param cra [Cra] CRA parent
          # @param mission_id [String] ID de la mission
          # @param date [Date] Date de l'entrée
          # @param exclude_entry_id [String] ID d'entrée à exclure (pour les mises à jour)
          # @raise [CraErrors::DuplicateEntryError] Si une entrée existe déjà
          def check_duplicate_entry!(cra, mission_id, date, exclude_entry_id = nil)
            return if mission_id.blank? || date.blank?

            query = CraEntry.joins(:cra_entry_cras, :cra_entry_missions)
                           .where(cra_entry_cras: { cra_id: cra.id })
                           .where(cra_entry_missions: { mission_id: mission_id })
                           .where(date: date)
                           .where(deleted_at: nil)

            query = query.where.not(id: exclude_entry_id) if exclude_entry_id.present?

            if query.exists?
              raise CraErrors::DuplicateEntryError, 'An entry already exists for this mission and date'
            end
          end

          # Validation de l'existence de la mission
          # @param mission_id [String] ID de la mission
          # @raise [CraErrors::MissionNotFoundError] Si la mission n'existe pas
          def check_mission_exists!(mission_id)
            return if mission_id.blank?

            mission = Mission.find_by(id: mission_id)
            raise CraErrors::MissionNotFoundError, 'Mission does not exist' unless mission.present?
          end

          # === VALIDATIONS ENTRÉES ===

          # Validation des paramètres d'entrée requis
          # @param entry_params [Hash] Paramètres d'entrée
          # @raise [CraErrors::InvalidPayloadError] Si des paramètres requis manquent
          def validate_required_params!(entry_params)
            required_fields = %i[date quantity unit_price]
            missing_fields = required_fields.select { |field| entry_params[field].blank? }

            if missing_fields.any?
              raise CraErrors::InvalidPayloadError.new(
                "Missing required parameters: #{missing_fields.join(', ')}",
                field: missing_fields.first
              )
            end
          end

          # Validation complète des paramètres d'entrée
          # @param entry_params [Hash] Paramètres d'entrée
          # @return [Hash] Paramètres validés et normalisés
          # @raise [CraErrors::InvalidPayloadError] Si des paramètres sont invalides
          def validate_and_normalize_entry_params(entry_params)
            validate_required_params!(entry_params)

            # Validation et normalisation des paramètres
            validated_params = entry_params.dup

            # Validation de la date
            if entry_params[:date].present?
              validated_params[:date] = validate_date_format(entry_params[:date])
            end

            # Validation de la quantité
            if entry_params[:quantity].present?
              validated_params[:quantity] = validate_quantity(entry_params[:quantity])
            end

            # Validation du prix unitaire
            if entry_params[:unit_price].present?
              validated_params[:unit_price] = validate_unit_price(entry_params[:unit_price])
            end

            # Validation de la description
            if entry_params[:description].present?
              validated_params[:description] = validate_description(entry_params[:description])
            end

            validated_params
          end

          # === MÉTHODES UTILITAIRES ===

          # Extraction et validation du mission_id depuis les paramètres
          # @param params [ActionController::Parameters] Paramètres de la requête
          # @param entry_params [Hash] Paramètres d'entrée
          # @return [String] Mission ID validé
          def extract_mission_id(params, entry_params = nil)
            params[:mission_id] ||
            params.dig(:entry_params, :mission_id) ||
            entry_params&.dig(:mission_id)
          end

          # Construction des attributs d'entrée validés
          # @param entry_params [Hash] Paramètres d'entrée
          # @return [Hash] Attributs pour la création/mise à jour
          def build_entry_attributes(entry_params)
            validated_params = validate_entry_params!(entry_params)

            {
              date: validated_params[:date],
              quantity: validated_params[:quantity],
              unit_price: validated_params[:unit_price],
              description: validated_params[:description]&.strip
            }.compact
          end
        end
      end
    end
  end
end
