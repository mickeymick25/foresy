# frozen_string_literal: true

require 'rails_helper'

# W4-D2 — Caractérisation des concerns (P6 Wave 4)
#
# Approche hybride B + C (arbitrage CTO 20/09) :
# - B : Class.new(ActionController::Base) pour les méthodes de concern
#   nécessitant le contexte Rails (helper_method) mais exercées
#   directement sans route ni cycle HTTP.
# - C : request specs via les contrôleurs réels pour les chemins
#   dépendant de render, response.headers, et du flow HTTP.
#
# Les concerns ne sont pas des services PORO : ce sont des mixins de
# contrôleur Rails. Le contexte Rails fait partie du contrat d'exécution.

# ============================================================
# B — Harness ActionController::Base pour les méthodes autonomes
# ============================================================
RSpec.describe Common::ParameterExtractor, type: :controller do
  # Harness : petit contrôleur Rails réel incluant le concern
  # (helper_method, params, request gratuits — pas de route nécessaire)
  controller(ApplicationController) do
    include Common::ParameterExtractor

    def index
      render json: extract_pagination_params
    end
  end

  describe 'extract_pagination_params' do
    it 'borne page et per_page' do
      controller.params = ActionController::Parameters.new(page: '0', per_page: '500')

      result = controller.send(:extract_pagination_params)

      expect(result).to eq(page: 1, per_page: 100)
    end
  end

  describe 'extract_sort_params' do
    it 'retombe sur les défauts si le tri n est pas asc/desc' do
      controller.params = ActionController::Parameters.new(sort: 'name', direction: 'lateral')

      result = controller.send(:extract_sort_params, :id, :desc)

      expect(result).to eq(field: :name, direction: :desc)
    end

    it 'accepte asc et desc' do
      controller.params = ActionController::Parameters.new(sort: 'name', direction: 'asc')

      result = controller.send(:extract_sort_params, :id, :desc)

      expect(result).to eq(field: :name, direction: :asc)
    end
  end

  describe 'extract_date_range_params' do
    it 'parse les dates présentes et ignore les invalides' do
      controller.params = ActionController::Parameters.new(start_date: '2026-01-15', end_date: 'not-a-date')

      result = controller.send(:extract_date_range_params)

      expect(result[:start_date]).to eq(Date.new(2026, 1, 15))
      expect(result[:end_date]).to be_nil
      expect(result[:range_valid?]).to be(false)
    end

    it 'retourne range_valid? true quand les dates sont valides' do
      controller.params = ActionController::Parameters.new(start_date: '2026-01-15', end_date: '2026-02-20')

      result = controller.send(:extract_date_range_params)

      expect(result[:range_valid?]).to be(true)
    end
  end

  describe 'extract_filter_params' do
    it 'filtre les params autorisés' do
      controller.params = ActionController::Parameters.new(status: 'draft', year: '2026', unpermitted: 'x')

      result = controller.send(:extract_filter_params, %i[status year])

      expect(result).to eq(status: 'draft', year: '2026')
    end

    it 'retourne un hash vide si aucun paramètre autorisé n est présent' do
      controller.params = ActionController::Parameters.new(unpermitted: 'x')

      result = controller.send(:extract_filter_params, %i[status year])

      expect(result).to eq({})
    end
  end

  describe 'extract_search_params' do
    it 'strip et presence' do
      controller.params = ActionController::Parameters.new(search: '  test  ')

      expect(controller.send(:extract_search_params)).to eq('test')
    end

    it 'retourne nil si la recherche est absente' do
      controller.params = ActionController::Parameters.new({})

      expect(controller.send(:extract_search_params)).to be_nil
    end
  end
end