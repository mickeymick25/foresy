# frozen_string_literal: true

# 🔴 P4.6 — Suppression des default_scope (audit point M2)
#
# Les modèles Company, Cra, CraEntry, Mission utilisaient
# `default_scope { where(deleted_at: nil) }`, un anti-pattern Rails qui rend
# les requêtes implicites et difficiles à déboguer.
#
# Ce spec caractérise le remplacement par des scopes explicites :
#   - .active       -> where(deleted_at: nil)
#   - .with_deleted -> unscope(where: :deleted_at)  (tout, y compris supprimés)
#   - .only_deleted -> where.not(deleted_at: nil)  (uniquement supprimés)
#   - .deleted      -> where.not(deleted_at: nil)  (FC-08 v3.2.3 §29 — Company)
#
# Invariants vérifiés pour chaque modèle :
# 1. Aucun default_scope (Model.all n'ajoute pas de filtre deleted_at)
# 2. Les scopes explicites existent et se comportent correctement
# 3. Comportemental : un enregistrement soft-deleté est exclu de .active,
#    présent dans .with_deleted et dans .only_deleted / .deleted

require 'rails_helper'

# Modèles concernés par l'audit point M2 (anti-pattern default_scope).
SOFT_DELETE_MODELS = [Company, Cra, CraEntry, Mission].freeze

RSpec.describe 'P4.6 — Suppression des default_scope' do
  describe 'absence de default_scope' do
    SOFT_DELETE_MODELS.each do |model|
      it "#{model.name} n'a pas de default_scope (Model.all n'ajoute pas deleted_at)" do
        # Sans default_scope, Model.all == Model.unscoped (aucun WHERE sur deleted_at).
        expect(model.all.to_sql).to eq(model.unscoped.to_sql)
        expect(model.all.to_sql).not_to match(/deleted_at/i)
      end
    end
  end

  describe 'scopes explicites .active / .with_deleted / .deleted (FC-08 §29) ou .only_deleted' do
    it 'Company expose .active, .with_deleted et .deleted (FC-08 v3.2.3 §29)' do
      expect(Company).to respond_to(:active)
      expect(Company).to respond_to(:with_deleted)
      expect(Company).to respond_to(:deleted)
    end

    (SOFT_DELETE_MODELS - [Company]).each do |model|
      it "#{model.name} expose .active, .with_deleted et .only_deleted" do
        expect(model).to respond_to(:active)
        expect(model).to respond_to(:with_deleted)
        expect(model).to respond_to(:only_deleted)
      end
    end
  end

  describe 'comportement des scopes par modèle' do
    shared_examples 'soft-delete scopes explicites' do |model_class, factory_name, deleted_scope: :only_deleted|
      let!(:active_record) { create(factory_name) }
      let!(:deleted_record) do
        record = create(factory_name)
        # On positionne directement deleted_at pour isoler le comportement des
        # scopes des règles métier de #discard (qui peuvent refuser la suppression).
        record.update_columns(deleted_at: Time.current)
        record
      end

      after do
        model_class.with_deleted.delete_all
      end

      it '.active exclut les enregistrements supprimés' do
        expect(model_class.active).to include(active_record)
        expect(model_class.active).not_to include(deleted_record)
      end

      it '.with_deleted inclut tout (actifs et supprimés)' do
        expect(model_class.with_deleted).to include(active_record)
        expect(model_class.with_deleted).to include(deleted_record)
      end

      it ".#{deleted_scope} ne retourne que les supprimés" do
        expect(model_class.public_send(deleted_scope)).to include(deleted_record)
        expect(model_class.public_send(deleted_scope)).not_to include(active_record)
      end
    end

    it_behaves_like 'soft-delete scopes explicites', Company, :company, deleted_scope: :deleted
    it_behaves_like 'soft-delete scopes explicites', Cra, :cra
    it_behaves_like 'soft-delete scopes explicites', CraEntry, :cra_entry
    it_behaves_like 'soft-delete scopes explicites', Mission, :mission
  end
end
