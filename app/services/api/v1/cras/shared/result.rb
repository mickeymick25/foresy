# frozen_string_literal: true

module Api
  module V1
    module Cras
      module Shared
        # Unified Result struct for CRA Services API
        # Implements Platinum Level contract for consistent Service → Controller communication
        #
        # CONTRACT STRUCTURE:
        # {
        #   success: boolean,
        #   data: {
        #     item: { data: { ... } },           # Single CRA
        #     items: { data: [...], meta: {...} }, # Collection of CRAs
        #     pagination: { ... }               # Pagination info
        #     totals: { ... }                   # Totals info (if needed)
        #   },
        #   errors: [...],
        #   error_type: symbol
        # }
        #
        # USAGE:
        # Result.success_cra(cra)
        # Result.success_cras(cras, pagination: pagination_info)
        # Result.failure(errors, error_type)
        Result = Struct.new(:success, :data, :errors, :error_type, keyword_init: true) do
          def success?
            success == true
          end

          def failure?
            success == false
          end

          def value
            success? ? data : nil
          end

          def value!
            raise "Cannot call value! on failed result" unless success?
            data
          end

          # Factory methods for different scenarios
          def self.success(item: nil, items: nil, pagination: nil, totals: nil)
            validate_success_params(item, items)

            data = build_data(item, items, pagination, totals)
            new(success: true, data: data, errors: nil, error_type: nil)
          end

          def self.failure(errors, error_type)
            new(success: false, data: nil, errors: errors, error_type: error_type)
          end

          # Convenience methods for common use cases
          def self.success_cra(cra)
            raise ArgumentError, "CRA cannot be nil" unless cra.present?

            serialized_cra = CraSerializer.new(cra).serialize

            new(
              success: true,
              data: {
                item: serialized_cra
              },
              errors: nil,
              error_type: nil
            )
          end

          def self.success_cras(cras, pagination: nil, totals: nil)
            raise ArgumentError, "CRAs cannot be nil" unless cras.present?

            serialized_cras = CraSerializer.collection(cras)

            # Merge pagination info if provided
            if pagination.present?
              serialized_cras[:meta][:pagination] = pagination
            end

            # Merge totals info if provided
            if totals.present?
              serialized_cras[:meta][:totals] = totals
            end

            new(
              success: true,
              data: {
                items: serialized_cras
              },
              errors: nil,
              error_type: nil
            )
          end

          # Helper for backward compatibility with existing pagination structure
          def self.success_with_pagination(cras, pagination)
            success_cras(cras, pagination: pagination)
          end

          private

          def self.validate_success_params(item, items)
            if item.present? && items.present?
              raise ArgumentError, "Cannot specify both item and items"
            end

            if item.nil? && items.nil?
              raise ArgumentError, "Must specify either item or items"
            end
          end

          def self.build_data(item, items, pagination, totals)
            data = {}

            if item.present?
              serialized_cra = CraSerializer.new(item).serialize
              data[:item] = serialized_cra
            elsif items.present?
              serialized_cras = CraSerializer.collection(items)

              # Add pagination to meta if provided
              if pagination.present?
                serialized_cras[:meta][:pagination] = pagination
              end

              # Add totals to meta if provided
              if totals.present?
                serialized_cras[:meta][:totals] = totals
              end

              data[:items] = serialized_cras
            end

            data
          end
        end
      end
    end
  end
end
