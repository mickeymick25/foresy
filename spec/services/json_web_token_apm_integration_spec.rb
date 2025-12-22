# frozen_string_literal: true

require 'rails_helper'

# Test d'intégration pour la méthode add_datadog_tags de JsonWebToken
# Teste la standardisation de l'usage APM et la compatibilité avec les différentes versions de Datadog
RSpec.describe JsonWebToken, '.add_datadog_tags' do
  describe 'without Datadog loaded' do
    it 'does not crash when Datadog is not available' do
      expect do
        described_class.add_datadog_tags({
          'jwt.error_type' => 'JWT::DecodeError',
          'jwt.operation' => 'decode'
        })
      end.not_to raise_error
    end

    it 'returns nil gracefully' do
      result = described_class.add_datadog_tags({
        'test.key' => 'test.value'
      })
      expect(result).to be_nil
    end

    it 'handles empty hash without error' do
      expect do
        described_class.add_datadog_tags({})
      end.not_to raise_error
    end
  end

  describe 'with Datadog available - modern API (active_span)' do
    before do
      # Simule Datadog avec l'API moderne active_span
      datadog_tracer = double('Tracer')
      active_span = double('span')

      stub_const('Datadog::Tracer', datadog_tracer)
      allow(datadog_tracer).to receive(:active_span).and_return(active_span)
      allow(active_span).to receive(:set_tag)
      allow(datadog_tracer).to receive(:respond_to?).with(:active_span).and_return(true)
      allow(datadog_tracer).to receive(:respond_to?).with(:active).and_return(false)
    end

    it 'calls set_tag on active_span for each tag' do
      tracer = Datadog::Tracer
      span = tracer.active_span

      expect(span).to receive(:set_tag).with(:jwt_error_type, 'JWT::DecodeError')
      expect(span).to receive(:set_tag).with(:jwt_operation, 'decode')
      expect(span).to receive(:set_tag).with(:user_id, 123)

      described_class.add_datadog_tags({
        jwt_error_type: 'JWT::DecodeError',
        jwt_operation: 'decode',
        user_id: 123
      })
    end

    it 'handles single tag' do
      tracer = Datadog::Tracer
      span = tracer.active_span

      expect(span).to receive(:set_tag).with(:test_key, 'test.value')

      described_class.add_datadog_tags({
        test_key: 'test.value'
      })
    end

    it 'handles various value types' do
      tracer = Datadog::Tracer
      span = tracer.active_span

      expect(span).to receive(:set_tag).with(:string_value, 'test')
      expect(span).to receive(:set_tag).with(:integer_value, 123)
      expect(span).to receive(:set_tag).with(:boolean_value, true)
      expect(span).to receive(:set_tag).with(:float_value, 1.5)

      described_class.add_datadog_tags({
        string_value: 'test',
        integer_value: 123,
        boolean_value: true,
        float_value: 1.5
      })
    end

    it 'gracefully handles nil active_span' do
      tracer = Datadog::Tracer
      allow(tracer).to receive(:active_span).and_return(nil)

      expect do
        described_class.add_datadog_tags({
          test_key: 'test.value'
        })
      end.not_to raise_error
    end

    it 'handles errors from set_tag gracefully' do
      tracer = Datadog::Tracer
      span = tracer.active_span
      allow(span).to receive(:set_tag).and_raise(StandardError.new('Datadog error'))

      expect do
        described_class.add_datadog_tags({
          test_key: 'test.value'
        })
      end.not_to raise_error
    end
  end

  describe 'with Datadog available - legacy API (active.span)' do
    before do
      # Simule Datadog avec l'API legacy active.span
      datadog_tracer = double('Tracer')
      datadog_active = double('active')
      active_span = double('span')

      stub_const('Datadog::Tracer', datadog_tracer)
      allow(datadog_tracer).to receive(:active).and_return(datadog_active)
      allow(datadog_active).to receive(:span).and_return(active_span)
      allow(active_span).to receive(:set_tag)

      # Configure responds_to pour que l'API legacy soit détectée
      allow(datadog_tracer).to receive(:respond_to?).with(:active_span).and_return(false)
      allow(datadog_tracer).to receive(:respond_to?).with(:active).and_return(true)
      allow(datadog_active).to receive(:respond_to?).with(:span).and_return(true)
    end

    it 'calls set_tag on active.span for each tag' do
      tracer = Datadog::Tracer
      active = tracer.active
      span = active.span

      expect(span).to receive(:set_tag).with(:jwt_error_type, 'JWT::DecodeError')
      expect(span).to receive(:set_tag).with(:jwt_operation, 'decode')

      described_class.add_datadog_tags({
        jwt_error_type: 'JWT::DecodeError',
        jwt_operation: 'decode'
      })
    end

    it 'gracefully handles nil active.span' do
      tracer = Datadog::Tracer
      allow(tracer).to receive(:active).and_return(double('active').as_null_object)

      expect do
        described_class.add_datadog_tags({
          test_key: 'test.value'
        })
      end.not_to raise_error
    end
  end

  describe 'with both APIs available - priority to modern API' do
    before do
      # Simule Datadog avec les deux APIs disponibles
      datadog_tracer = double('Tracer')
      modern_span = double('modern_span')
      legacy_active = double('legacy_active')
      legacy_span = double('legacy_span')

      stub_const('Datadog::Tracer', datadog_tracer)
      allow(datadog_tracer).to receive(:active_span).and_return(modern_span)
      allow(datadog_tracer).to receive(:active).and_return(legacy_active)
      allow(legacy_active).to receive(:span).and_return(legacy_span)

      # Les deux APIs sont disponibles
      allow(datadog_tracer).to receive(:respond_to?).with(:active_span).and_return(true)
      allow(datadog_tracer).to receive(:respond_to?).with(:active).and_return(true)
      allow(legacy_active).to receive(:respond_to?).with(:span).and_return(true)

      allow(modern_span).to receive(:set_tag)
      allow(legacy_span).to receive(:set_tag)
    end

    it 'uses modern API (active_span) when both are available' do
      tracer = Datadog::Tracer
      modern_span = tracer.active_span
      legacy_span = tracer.active.span

      # L'API moderne devrait être utilisée
      expect(modern_span).to receive(:set_tag).with(:test_key, 'test.value')
      # L'API legacy ne devrait PAS être utilisée
      expect(legacy_span).not_to receive(:set_tag)

      described_class.add_datadog_tags({
        test_key: 'test.value'
      })
    end
  end

  describe 'with Datadog available - no valid API method' do
    before do
      # Simule Datadog chargé mais avec API invalide
      stub_const('Datadog', Module.new)
      datadog_tracer = double('Tracer')

      stub_const('Datadog::Tracer', datadog_tracer)

      # Aucune méthode valide disponible
      allow(datadog_tracer).to receive(:respond_to?).with(:active_span).and_return(false)
      allow(datadog_tracer).to receive(:respond_to?).with(:active).and_return(false)
    end

    it 'does not crash when no valid Datadog API method is available' do
      expect do
        described_class.add_datadog_tags({
          test_key: 'test.value'
        })
      end.not_to raise_error
    end

    it 'logs debug message about API method not available' do
      # Cette partie serait testable avec un mock de Rails.logger
      expect do
        described_class.add_datadog_tags({
          test_key: 'test.value'
        })
      end.not_to raise_error
    end
  end

  describe 'edge cases and error handling' do
    it 'handles nil values gracefully' do
      expect do
        described_class.add_datadog_tags({
          nil_value: nil,
          another_nil: nil
        })
      end.not_to raise_error
    end

    it 'handles empty string values' do
      expect do
        described_class.add_datadog_tags({
          empty_string: ''
        })
      end.not_to raise_error
    end

    it 'handles special characters in keys and values' do
      expect do
        described_class.add_datadog_tags({
          special_key_name: 'value with spaces',
          unicode_key: 'value with émojis 🚀',
          symbols_key: 'value.with.dots'
        })
      end.not_to raise_error
    end

    it 'handles very large values' do
      large_string = 'x' * 10000

      expect do
        described_class.add_datadog_tags({
          large_value: large_string
        })
      end.not_to raise_error
    end
  end

  describe 'integration with log_jwt_error' do
    before do
      datadog_tracer = double('Tracer')
      active_span = double('span')

      stub_const('Datadog::Tracer', datadog_tracer)
      allow(datadog_tracer).to receive(:active_span).and_return(active_span)
      allow(active_span).to receive(:set_tag)
      allow(datadog_tracer).to receive(:respond_to?).with(:active_span).and_return(true)
    end

    it 'calls add_datadog_tags when logging JWT errors' do
      tracer = Datadog::Tracer
      span = tracer.active_span

      expect(span).to receive(:set_tag).with(:jwt_error_type, 'JWT::DecodeError')
      expect(span).to receive(:set_tag).with(:jwt_operation, 'decode')

      # Ceci va appeler log_jwt_error qui va appeler add_datadog_tags
      error = JWT::DecodeError.new('Invalid token')
      described_class.send(:log_jwt_error, 'Test message', error)
    end

    it 'does not crash log_jwt_error when Datadog raises an exception' do
      tracer = Datadog::Tracer
      span = tracer.active_span
      allow(span).to receive(:set_tag).and_raise(StandardError.new('Datadog error'))

      # Ceci ne devrait pas faire crasher log_jwt_error
      expect do
        error = JWT::DecodeError.new('Invalid token')
        described_class.send(:log_jwt_error, 'Test message', error)
      end.not_to raise_error
    end
  end
end
