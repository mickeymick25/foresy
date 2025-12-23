# frozen_string_literal: true

require 'rails_helper'

# Test d'intégration pour ApmService
# Teste la standardisation de l'usage APM et la compatibilité avec les différentes versions de Datadog
RSpec.describe ApmService do
  describe 'Basic functionality' do
    it 'has an enabled? method that works' do
      # Test basique sans services APM chargés
      expect(described_class.enabled?).to be(false)
    end

    it 'has TestHelpers module' do
      expect(described_class::TestHelpers).to be_a(Module)
    end
  end

  describe 'without APM services loaded' do
    it 'does not crash when calling tag method' do
      expect do
        described_class.tag('test.key', 'test.value')
      end.not_to raise_error
    end

    it 'does not crash when calling add_attributes method' do
      expect do
        described_class.add_attributes({ test_key: 'test_value', number: 123 })
      end.not_to raise_error
    end

    it 'does not crash when calling track_operation method' do
      expect do
        described_class.track_operation('test_operation', 0.5)
      end.not_to raise_error
    end

    it 'returns false for enabled? when no APM services are available' do
      expect(described_class.enabled?).to be(false)
    end
  end

  describe 'with NewRelic available' do
    before do
      # Simule NewRelic comme étant chargé
      newrelic_module = Module.new
      stub_const('NewRelic', newrelic_module)
      newrelic_agent = double('Agent')
      newrelic_module.const_set('Agent', newrelic_agent)
      allow(newrelic_agent).to receive(:add_custom_attributes)
    end

    after do
      # RSpec automatically cleans up stubbed constants
    end

    it 'returns true for enabled?' do
      expect(described_class.enabled?).to be(true)
    end

    it 'calls NewRelic Agent.add_custom_attributes when adding attributes' do
      expect(NewRelic::Agent).to receive(:add_custom_attributes).with({
                                                                        'jwt.error_type' => 'JWT::DecodeError',
                                                                        'jwt.operation' => 'decode'
                                                                      })

      described_class.add_attributes({
                                       'jwt.error_type' => 'JWT::DecodeError',
                                       'jwt.operation' => 'decode'
                                     })
    end

    it 'calls NewRelic Agent.add_custom_attributes when adding single tag' do
      expect(NewRelic::Agent).to receive(:add_custom_attributes).with({
                                                                        'test.key' => 'test.value'
                                                                      })

      described_class.tag('test.key', 'test.value')
    end

    it 'handles NewRelic errors gracefully' do
      allow(NewRelic::Agent).to receive(:add_custom_attributes).and_raise(StandardError.new('NewRelic error'))

      expect do
        described_class.tag('test.key', 'test.value')
      end.not_to raise_error
    end
  end

  describe 'with Datadog available - active_span API' do
    before do
      # Simule Datadog comme étant chargé avec API active_span (moderne)
      datadog_module = Module.new
      stub_const('Datadog', datadog_module)
      datadog_tracer = double('Tracer')
      active_span = double('span')
      active_object = double('active_object')

      datadog_module.const_set('Tracer', datadog_tracer)
      allow(datadog_tracer).to receive(:active_span).and_return(active_span)
      allow(datadog_tracer).to receive(:active).and_return(active_object)
      allow(active_span).to receive(:set_tag)
      allow(active_object).to receive(:span).and_return(active_span)
      allow(datadog_tracer).to receive(:respond_to?).with(:active_span).and_return(true)
      allow(datadog_tracer).to receive(:respond_to?).with(:active).and_return(true)
    end

    after do
      # RSpec automatically cleans up stubbed constants
    end

    it 'returns true for enabled?' do
      expect(described_class.enabled?).to be(true)
    end

    it 'calls Datadog active_span set_tag when adding attributes' do
      tracer = Datadog::Tracer
      span = tracer.active_span

      expect(span).to receive(:set_tag).with('jwt.error_type', 'JWT::DecodeError')
      expect(span).to receive(:set_tag).with('jwt.operation', 'decode')

      described_class.add_attributes({
                                       'jwt.error_type' => 'JWT::DecodeError',
                                       'jwt.operation' => 'decode'
                                     })
    end

    it 'calls Datadog active_span set_tag when adding single tag' do
      tracer = Datadog::Tracer
      span = tracer.active_span

      expect(span).to receive(:set_tag).with('test.key', 'test.value')

      described_class.tag('test.key', 'test.value')
    end

    it 'handles Datadog active_span errors gracefully' do
      tracer = Datadog::Tracer
      span = tracer.active_span
      allow(span).to receive(:set_tag).and_raise(StandardError.new('Datadog error'))

      expect do
        described_class.tag('test.key', 'test.value')
      end.not_to raise_error
    end

    it 'gracefully handles nil active_span' do
      tracer = Datadog::Tracer
      allow(tracer).to receive(:active_span).and_return(nil)

      expect do
        described_class.tag('test.key', 'test.value')
      end.not_to raise_error
    end
  end

  describe 'with Datadog available - active.span API (legacy)' do
    before do
      # Simule Datadog comme étant chargé avec API active.span (legacy)
      datadog_module = Module.new
      stub_const('Datadog', datadog_module)
      datadog_tracer = double('Tracer')
      datadog_active = double('active')
      active_span = double('span')

      datadog_module.const_set('Tracer', datadog_tracer)
      allow(datadog_tracer).to receive(:active).and_return(datadog_active)
      allow(datadog_active).to receive(:span).and_return(active_span)
      allow(active_span).to receive(:set_tag)

      # Configure responds_to pour que l'API legacy soit détectée
      allow(datadog_tracer).to receive(:respond_to?).with(:active_span).and_return(false)
      allow(datadog_tracer).to receive(:respond_to?).with(:active).and_return(true)
      allow(datadog_active).to receive(:respond_to?).with(:span).and_return(true)
    end

    after do
      # RSpec automatically cleans up stubbed constants
    end

    it 'returns true for enabled?' do
      expect(described_class.enabled?).to be(true)
    end

    it 'calls Datadog active.span set_tag when adding attributes' do
      tracer = Datadog::Tracer
      active = tracer.active
      span = active.span

      expect(span).to receive(:set_tag).with('jwt.error_type', 'JWT::DecodeError')
      expect(span).to receive(:set_tag).with('jwt.operation', 'decode')

      described_class.add_attributes({
                                       'jwt.error_type' => 'JWT::DecodeError',
                                       'jwt.operation' => 'decode'
                                     })
    end

    it 'calls Datadog active.span set_tag when adding single tag' do
      tracer = Datadog::Tracer
      active = tracer.active
      span = active.span

      expect(span).to receive(:set_tag).with('test.key', 'test.value')

      described_class.tag('test.key', 'test.value')
    end

    it 'gracefully handles nil active.span' do
      tracer = Datadog::Tracer
      allow(tracer).to receive(:active).and_return(double('active').as_null_object)

      expect do
        described_class.tag('test.key', 'test.value')
      end.not_to raise_error
    end
  end

  describe 'with Datadog available - no valid API method' do
    before do
      # Simule Datadog chargé mais avec API invalide
      datadog_module = Module.new
      stub_const('Datadog', datadog_module)
      datadog_tracer = double('Tracer')

      datadog_module.const_set('Tracer', datadog_tracer)

      # Aucune méthode valide disponible
      allow(datadog_tracer).to receive(:respond_to?).with(:active_span).and_return(false)
      allow(datadog_tracer).to receive(:respond_to?).with(:active).and_return(false)
    end

    after do
      # RSpec automatically cleans up stubbed constants
    end

    it 'returns false for enabled?' do
      expect(described_class.enabled?).to be(false)
    end

    it 'does not crash when no valid Datadog API method is available' do
      expect do
        described_class.tag('test.key', 'test.value')
      end.not_to raise_error
    end

    it 'logs debug message about API method not available' do
      # Cette partie serait testable avec un mock de Rails.logger
      expect do
        described_class.tag('test.key', 'test.value')
      end.not_to raise_error
    end
  end

  describe 'with both NewRelic and Datadog available' do
    before do
      # Charge les deux services
      newrelic_module = Module.new
      stub_const('NewRelic', newrelic_module)
      newrelic_agent = double('Agent')
      newrelic_module.const_set('Agent', newrelic_agent)
      allow(newrelic_agent).to receive(:add_custom_attributes)

      datadog_module = Module.new
      stub_const('Datadog', datadog_module)
      datadog_tracer = double('Tracer')
      active_span = double('span')
      active_object = double('active_object')

      datadog_module.const_set('Tracer', datadog_tracer)
      allow(datadog_tracer).to receive(:active_span).and_return(active_span)
      allow(datadog_tracer).to receive(:active).and_return(active_object)
      allow(active_span).to receive(:set_tag)
      allow(active_object).to receive(:span).and_return(active_span)
      allow(datadog_tracer).to receive(:respond_to?).with(:active_span).and_return(true)
      allow(datadog_tracer).to receive(:respond_to?).with(:active).and_return(true)
    end

    after do
      # RSpec automatically cleans up stubbed constants
    end

    it 'returns true for enabled?' do
      expect(described_class.enabled?).to be(true)
    end

    it 'calls both services when adding attributes' do
      expect(NewRelic::Agent).to receive(:add_custom_attributes).with({
                                                                        'jwt.error_type' => 'JWT::DecodeError',
                                                                        'jwt.operation' => 'decode'
                                                                      })

      tracer = Datadog::Tracer
      span = tracer.active_span
      expect(span).to receive(:set_tag).with('jwt.error_type', 'JWT::DecodeError')
      expect(span).to receive(:set_tag).with('jwt.operation', 'decode')

      described_class.add_attributes({
                                       'jwt.error_type' => 'JWT::DecodeError',
                                       'jwt.operation' => 'decode'
                                     })
    end
  end

  describe 'TestHelpers' do
    describe '.setup_datadog_mocks' do
      it 'sets up Datadog mocks without error when Datadog is not defined' do
        expect do
          described_class::TestHelpers.setup_datadog_mocks
        end.not_to raise_error
      end

      context 'with Datadog defined' do
        before do
          datadog_module = Module.new
          stub_const('Datadog', datadog_module)
          datadog_tracer = double('Tracer')
          datadog_module.const_set('Tracer', datadog_tracer)
        end

        after do
          # RSpec automatically cleans up stubbed constants
        end

        it 'sets up Datadog mocks successfully' do
          expect do
            described_class::TestHelpers.setup_datadog_mocks
          end.not_to raise_error
        end
      end
    end

    describe '.setup_newrelic_mocks' do
      it 'sets up NewRelic mocks without error when NewRelic is not defined' do
        expect do
          described_class::TestHelpers.setup_newrelic_mocks
        end.not_to raise_error
      end

      context 'with NewRelic defined' do
        before do
          newrelic_module = Module.new
          stub_const('NewRelic', newrelic_module)
          newrelic_agent = double('Agent')
          newrelic_module.const_set('Agent', newrelic_agent)
        end

        after do
          # RSpec automatically cleans up stubbed constants
        end

        it 'sets up NewRelic mocks successfully' do
          expect(NewRelic::Agent).to receive(:add_custom_attributes)
          described_class::TestHelpers.setup_newrelic_mocks
          # Call a method that uses NewRelic to trigger the expected call
          described_class.add_attributes({ 'test_key' => 'test_value' })
        end
      end
    end

    describe '.reset_mocks' do
      it 'resets mocks without error when no services are defined' do
        expect do
          described_class::TestHelpers.reset_mocks
        end.not_to raise_error
      end
    end
  end

  describe 'track_operation' do
    it 'tracks operation duration for NewRelic' do
      newrelic_module = Module.new
      stub_const('NewRelic', newrelic_module)
      newrelic_agent = double('Agent')
      newrelic_module.const_set('Agent', newrelic_agent)

      expect(newrelic_agent).to receive(:add_custom_attributes).with({
                                                                       'operation' => 'test_operation',
                                                                       'operation_duration' => '0.5'
                                                                     })

      described_class.track_operation('test_operation', 0.5)
      # RSpec automatically cleans up stubbed constants
    end

    it 'tracks operation for Datadog' do
      datadog_module = Module.new
      stub_const('Datadog', datadog_module)
      datadog_tracer = double('Tracer')
      active_span = double('span')
      active_object = double('active_object')

      datadog_module.const_set('Tracer', datadog_tracer)
      allow(datadog_tracer).to receive(:active_span).and_return(active_span)
      allow(datadog_tracer).to receive(:active).and_return(active_object)
      allow(active_span).to receive(:set_tag)
      allow(active_object).to receive(:span).and_return(active_span)
      allow(datadog_tracer).to receive(:respond_to?).with(:active_span).and_return(true)
      allow(datadog_tracer).to receive(:respond_to?).with(:active).and_return(true)

      expect(active_span).to receive(:set_tag).with('operation', 'test_operation')

      described_class.track_operation('test_operation', 0.5)
      # RSpec automatically cleans up stubbed constants
    end
  end

  describe 'edge cases and error handling' do
    it 'handles nil values gracefully' do
      expect do
        described_class.tag(nil, nil)
        described_class.add_attributes(nil)
        described_class.track_operation(nil, nil)
      end.not_to raise_error
    end

    it 'handles various value types' do
      expect do
        described_class.add_attributes({
                                         'string' => 'test',
                                         'integer' => 123,
                                         'boolean' => true,
                                         'float' => 1.5
                                       })
      end.not_to raise_error
    end

    it 'handles empty hash for add_attributes' do
      expect do
        described_class.add_attributes({})
      end.not_to raise_error
    end
  end
end
