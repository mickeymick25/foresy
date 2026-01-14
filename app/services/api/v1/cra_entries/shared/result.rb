# frozen_string_literal: true

module Api
  module V1
    module CraEntries
      module Shared
        # Unified Result module for CRA Entries API
        # Implements Platinum Level contract for consistent Service → Controller communication
        #
        # CONTRACT STRUCTURE:
        # {
        #   success: boolean,
        #   data: {
        #     item: { data: { ... } },           # Single item
        #     items: { data: [...], meta: {...} }, # Collection
        #     cra: { data: { ... } }
        #   },
        #   errors: [...],
        #   error_type: symbol
        # }
        #
        # USAGE:
        # extend Shared::Result
        # Result.success(item: entry, cra: cra)
        # Result.success(items: entries, total_count: count, cra: cra)
        # Result.failure(errors, error_type)
        module Result
          # Represents the result of a service operation
          def self.success(success: true, data: nil, errors: nil, error_type: nil)
            ResultObject.new(success, data, errors, error_type)
          end

          def self.failure(errors, error_type)
            ResultObject.new(false, nil, errors, error_type)
          end

          # Factory methods for different scenarios
          def self.success_entry(entry, cra = nil)
            raise ArgumentError, "Entry cannot be nil" unless entry.present?

            serialized_entry = CraEntrySerializer.new(entry).serialize
            serialized_cra = cra.present? ? CraSerializer.new(cra).serialize : nil

            # UNIQUE CONTRACT STRUCTURE - All services must use this format
            success(
              success: true,
              data: {
                item: serialized_entry,
                cra: serialized_cra
              },
              errors: nil,
              error_type: nil
            )
          end

          # Aliases for backward compatibility with CreateService calls
          def self.fail(error:, status:, message: nil)
            failure([message || error.to_s], error)
          end

          def self.internal_error(error:, message: nil)
            failure([message || "An unexpected error occurred"], :internal_error)
          end

          def self.success_entries(entries, cra = nil, total_count: nil)
            raise ArgumentError, "Entries cannot be nil" unless entries.present?

            serialized_entries = CraEntrySerializer.collection(entries)
            serialized_cra = cra.present? ? CraSerializer.new(cra).serialize : nil

            # Add total_count to collection meta for pagination
            if total_count.present?
              serialized_entries[:meta][:total_count] = total_count
            end

            # UNIQUE CONTRACT STRUCTURE - All collections must use this format
            success(
              success: true,
              data: {
                items: serialized_entries,
                cra: serialized_cra
              },
              errors: nil,
              error_type: nil
            )
          end

          # Private helper methods
          def self.validate_success_params(item, items)
            if item.present? && items.present?
              raise ArgumentError, "Cannot specify both item and items"
            end

            if item.nil? && items.nil?
              raise ArgumentError, "Must specify either item or items"
            end
          end

          private_class_method :validate_success_params

          def self.build_data(item, items, total_count, cra)
            data = {}

            if item.present?
              serialized_entry = CraEntrySerializer.new(item).serialize
              data[:item] = serialized_entry
            elsif items.present?
              serialized_entries = CraEntrySerializer.collection(items)
              # Add total_count to meta if provided
              if total_count.present?
                serialized_entries[:meta][:total_count] = total_count
              end
              data[:items] = serialized_entries
            end

            if cra.present?
              serialized_cra = CraSerializer.new(cra).serialize
              data[:cra] = serialized_cra
            end

            data
          end

          private_class_method :build_data
        end

        # Internal ResultObject class for encapsulating result state
        class ResultObject
          attr_reader :success, :data, :errors, :error_type

          def initialize(success, data, errors, error_type)
            @success = success
            @data = data
            @errors = errors
            @error_type = error_type
          end

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
        end
      end
    end
  end
end
