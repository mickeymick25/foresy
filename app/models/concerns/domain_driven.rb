# frozen_string_literal: true

# DomainDriven Concern
#
# Concern pour factoriser les associations via des tables de relation
# Implémente l'architecture Domain-Driven avec des tables de relation explicites
#
# Principe :
# - AUCUNE foreign key métier directe vers Mission, Company, etc.
# - TOUTES les relations via des tables de relation explicites
# - Entités pures avec logique métier complète
#
# Usage:
#   class Cra < ApplicationRecord
#     include DomainDriven
#
#     has_relation :missions, through: :cra_missions
#     has_relation :entries, through: :cra_entry_cras, class_name: 'CraEntry'
#   end
#
#   class CraEntry < ApplicationRecord
#     include DomainDriven
#
#     has_relation :cras, through: :cra_entry_cras
#     has_relation :missions, through: :cra_entry_missions
#   end
module DomainDriven
  extend ActiveSupport::Concern

  included do
    class_attribute :relation_tables, default: {}
  end

  # Définir une association via une table de relation
  # @param name [Symbol] nom de l'association (ex: :missions)
  # @param through [Symbol] nom de la table de relation (ex: :cra_missions)
  # @param class_name [String] classe cible optionnelle
  # @param foreign_key [Symbol] clé étrangère optionnelle
  def self.has_relation(name, through:, class_name: nil, foreign_key: nil)
    define_method(name) do
      relation_table = self.class.relation_tables[name.to_s]
      return [] unless relation_table

      send("through_#{relation_table}_#{name}")
    end

    # Méthode pour accéder via la table de relation
    define_method("through_#{through}_#{name}") do
      through.to_s.classify.constantize
      relation_records = send(through)

      if class_name.present?
        relation_records.joins(foreign_key || name).where(foreign_key || "#{name}.id IS NOT NULL").map(&:"#{name}")
      else
        relation_records
      end
    end

    # Enregistrer la table de relation pour cette association
    self.relation_tables = relation_tables.merge(name.to_s => through.to_s)
  end

  # Méthodes utilitaires pour les relations via tables

  # Vérifier si une relation existe via la table de relation
  # @param relation_name [Symbol] nom de la relation
  # @param target_id [Integer] ID de l'enregistrement cible
  # @return [Boolean] true si la relation existe
  def related?(relation_name, target_id)
    relation_table = self.class.relation_tables[relation_name.to_s]
    return false unless relation_table

    send(relation_table).exists?(relation_name => { id: target_id })
  end

  # Ajouter une relation via la table de relation
  # @param relation_name [Symbol] nom de la relation
  # @param target [ActiveRecord::Base] enregistrement cible
  # @return [Boolean] true si la relation a été créée
  def add_relation!(relation_name, target)
    relation_table = self.class.relation_tables[relation_name.to_s]
    return false unless relation_table && target.present?

    relation_model = relation_table.classify.constantize
    foreign_key = relation_name.to_s.singularize

    begin
      relation_model.create!(
        self.class.name.underscore.to_sym => self,
        foreign_key => target
      )
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end

  # Supprimer une relation via la table de relation
  # @param relation_name [Symbol] nom de la relation
  # @param target [ActiveRecord::Base] enregistrement cible
  # @return [Boolean] true si la relation a été supprimée
  def remove_relation!(relation_name, target)
    relation_table = self.class.relation_tables[relation_name.to_s]
    return false unless relation_table && target.present?

    relation_model = relation_table.classify.constantize
    foreign_key = relation_name.to_s.singularize

    relation_model.where(
      self.class.name.underscore.to_sym => self,
      foreign_key => target
    ).destroy_all.any?
  end

  # Compter les relations via la table de relation
  # @param relation_name [Symbol] nom de la relation
  # @return [Integer] nombre de relations
  def relation_count(relation_name)
    relation_table = self.class.relation_tables[relation_name.to_s]
    return 0 unless relation_table

    send(relation_table).count
  end

  # Vérifier si toutes les relations peuvent être modifiées
  # @param relation_names [Array<Symbol>] noms des relations à vérifier
  # @return [Boolean] true si toutes les relations sont modifiables
  def all_relations_modifiable?(*relation_names)
    relation_names.all? { |name| relation_modifiable?(name) }
  end

  # Vérifier si une relation spécifique peut être modifiée
  # @param relation_name [Symbol] nom de la relation
  # @return [Boolean] true si la relation est modifiable
  def relation_modifiable?(relation_name)
    relation_table = self.class.relation_tables[relation_name.to_s]
    return true unless relation_table

    # Par défaut, les relations sont modifiables si l'enregistrement est actif
    # Cette logique peut être overridée par les modèles spécifiques
    active?
  end

  # Méthodes de classe pour les opérations sur les tables de relation
  class_methods do
    # Trouver tous les enregistrements qui ont une relation avec un target donné
    # @param relation_name [Symbol] nom de la relation
    # @param target [ActiveRecord::Base] enregistrement cible
    # @return [ActiveRecord::Relation] enregistrements qui ont la relation
    def with_relation(relation_name, target)
      relation_table = relation_tables[relation_name.to_s]
      return none unless relation_table && target.present?

      foreign_key = relation_name.to_s.singularize

      joins(relation_table).where(
        relation_table => { foreign_key => target.id }
      )
    end

    # Trouver tous les enregistrements qui n'ont pas de relation avec un target donné
    # @param relation_name [Symbol] nom de la relation
    # @param target [ActiveRecord::Base] enregistrement cible
    # @return [ActiveRecord::Relation] enregistrements sans la relation
    def without_relation(relation_name, target)
      relation_table = relation_tables[relation_name.to_s]
      return all unless relation_table && target.present?

      foreign_key = relation_name.to_s.singularize

      left_joins(relation_table).where(
        relation_table => { foreign_key => nil }
      )
    end

    # Obtenir les statistiques des relations
    # @param relation_name [Symbol] nom de la relation
    # @return [Hash] statistiques sur les relations
    def relation_statistics(relation_name)
      relation_table = relation_tables[relation_name.to_s]
      return { total: 0, average: 0, max: 0, min: 0 } unless relation_table

      stats = joins(relation_table).group(:id).count

      values = stats.values
      {
        total: stats.count,
        average: values.sum.to_f / values.count,
        max: values.max,
        min: values.min
      }
    end
  end
end
