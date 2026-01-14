# frozen_string_literal: true

# Serializer for Cra model
# Implements the standardized Result contract for CRA API responses
#
# Contract Format:
# {
#   data: {
#     id: uuid,
#     type: "cra",
#     attributes: { ... },
#     relationships: { ... }
#   }
# }
#
# Usage:
# CraSerializer.new(cra).serialize
# CraSerializer.collection(cras).serialize
class CraSerializer
  attr_reader :cra

  def initialize(cra)
    @cra = cra
  end

  # Serialize a single CRA
  def serialize
    return nil unless cra

    {
      data: {
        id: cra.id.to_s,
        type: "cra",
        attributes: {
          month: cra.month,
          year: cra.year,
          status: cra.status,
          description: cra.description,
          total_days: cra.total_days.to_f,
          total_amount: cra.total_amount.to_i,
          currency: cra.currency,
          created_at: cra.created_at&.iso8601,
          updated_at: cra.updated_at&.iso8601,
          locked_at: cra.locked_at&.iso8601
        },
        relationships: build_relationships
      }
    }
  end

  # Serialize a collection of CRAs
  def self.collection(cras)
    new_cras = cras.is_a?(ActiveRecord::Relation) ? cras : cras.compact
    {
      data: new_cras.map { |cra| new(cra).serialize[:data] },
      meta: {
        count: new_cras.size
      }
    }
  end

  # JSON API compliant relationships
  def build_relationships
    {
      user: build_user_relationship,
      company: build_company_relationship
    }.compact
  end

  private

  def build_user_relationship
    return nil unless cra.respond_to?(:user) && cra.user.present?

    {
      data: {
        id: cra.user.id.to_s,
        type: "user"
      }
    }
  end

  def build_company_relationship
    return nil unless cra.respond_to?(:company) && cra.company.present?

    {
      data: {
        id: cra.company.id.to_s,
        type: "company"
      }
    }
  end
end
