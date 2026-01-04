# 🚨 FC06 Exception System

**Feature Contract** : FC06 - Mission Management  
**Status Global** : ✅ **TERMINÉ - PR #12 MERGED**  
**Dernière mise à jour** : 31 décembre 2025 - Système d'exceptions finalisé  
**Version** : 1.0 (Finale)

---

## 🎯 Vue d'Ensemble du Système d'Exceptions

FC06 implémente un **système d'exceptions hiérarchisé et métier-spécifique** pour gérer tous les cas d'erreur liés à la gestion des missions. Ce système garantit une gestion d'erreurs cohérente, traçable et user-friendly tout en maintenant la robustesse technique.

### 🏗️ Architecture du Système d'Exceptions

Le système d'exceptions de FC06 est structuré en **hiérarchie pyramidale** :

1. **Base Exceptions** : Classes racine du système
2. **Domain Exceptions** : Exceptions métier spécifiques aux missions
3. **Infrastructure Exceptions** : Exceptions techniques (base de données, API)
4. **Validation Exceptions** : Exceptions de validation de données
5. **Lifecycle Exceptions** : Exceptions spécifiques aux transitions d'état

### 📊 Hiérarchie des Exceptions

```
StandardError (Ruby)
├── MissionErrors (FC06 Base)
│   ├── MissionValidationError
│   ├── MissionLifecycleError
│   ├── MissionAccessError
│   ├── MissionBusinessRuleError
│   └── MissionIntegrityError
├── CompanyErrors (Shared)
│   ├── CompanyAccessError
│   └── CompanyValidationError
└── InfrastructureErrors (Shared)
    ├── DatabaseError
    ├── APITransactionError
    └── ConcurrencyError
```

---

## 🏛️ MissionErrors - Exceptions Métier Principales

### Base MissionError

```ruby
# lib/mission_errors.rb
module MissionErrors
  class MissionError < StandardError
    attr_reader :mission_id, :context, :details
    
    def initialize(message = nil, mission_id: nil, context: nil, details: nil)
      super(message)
      @mission_id = mission_id
      @context = context
      @details = details
      
      # Log the error for debugging
      Rails.logger.error(self.class.name) do
        {
          message: message,
          mission_id: mission_id,
          context: context,
          details: details,
          backtrace: backtrace&.first(3)
        }.to_json
      end
    end
    
    def to_h
      {
        error: self.class.name.demodulize.underscore,
        message: message,
        mission_id: mission_id,
        context: context,
        details: details
      }
    end
  end
end
```

### MissionValidationError

```ruby
# Exception pour erreurs de validation métier
class MissionValidationError < MissionErrors::MissionError
  def initialize(field, value, rule, mission_id: nil)
    super(
      "Validation échouée pour #{field}: #{value} ne respecte pas la règle #{rule}",
      mission_id: mission_id,
      context: 'validation',
      details: { field: field, value: value, rule: rule }
    )
  end
  
  # Factory methods for common validation errors
  def self.mission_type_required(mission_id = nil)
    new('mission_type', nil, 'required', mission_id: mission_id)
  end
  
  def self.financial_data_inconsistent(mission_type, mission_id = nil)
    new('financial_data', mission_type, 'consistency', mission_id: mission_id)
  end
  
  def self.date_range_invalid(start_date, end_date, mission_id = nil)
    new('date_range', { start: start_date, end: end_date }, 'validity', mission_id: mission_id)
  end
end
```

### MissionLifecycleError

```ruby
# Exception pour erreurs de lifecycle
class MissionLifecycleError < MissionErrors::MissionError
  def initialize(current_status, target_status, rule, mission_id: nil)
    super(
      "Transition lifecycle invalide: #{current_status} → #{target_status} (#{rule})",
      mission_id: mission_id,
      context: 'lifecycle',
      details: { 
        current_status: current_status, 
        target_status: target_status, 
        rule: rule 
      }
    )
  end
  
  # Factory methods for lifecycle errors
  def self.invalid_transition(current_status, target_status, mission_id = nil)
    new(current_status, target_status, 'transition_not_allowed', mission_id: mission_id)
  end
  
  def self.prerequisite_not_met(current_status, target_status, prerequisite, mission_id = nil)
    new(current_status, target_status, "prerequisite_#{prerequisite}", mission_id: mission_id)
  end
  
  def self.business_rule_violation(status, rule, mission_id = nil)
    new(status, nil, "business_rule_#{rule}", mission_id: mission_id)
  end
end
```

### MissionAccessError

```ruby
# Exception pour erreurs d'accès
class MissionAccessError < MissionErrors::MissionError
  def initialize(access_type, user_id, mission_id, reason = nil)
    super(
      "Accès #{access_type} refusé pour l'utilisateur #{user_id} sur la mission #{mission_id}#{": #{reason}" if reason}",
      mission_id: mission_id,
      context: 'access_control',
      details: { 
        access_type: access_type, 
        user_id: user_id, 
        reason: reason 
      }
    )
  end
  
  # Factory methods for access errors
  def self.unauthorized_view(user_id, mission_id)
    new('view', user_id, mission_id, 'insufficient_permissions')
  end
  
  def self.unauthorized_modify(user_id, mission_id)
    new('modify', user_id, mission_id, 'not_creator')
  end
  
  def self.unauthorized_delete(user_id, mission_id)
    new('delete', user_id, mission_id, 'not_creator_or_cra_linked')
  end
  
  def self.company_not_linked(user_id, mission_id)
    new('access', user_id, mission_id, 'company_not_associated')
  end
end
```

### MissionBusinessRuleError

```ruby
# Exception pour violation de règles métier
class MissionBusinessRuleError < MissionErrors::MissionError
  def initialize(rule_name, details = {}, mission_id = nil)
    super(
      "Règle métier violée: #{rule_name} (#{details})",
      mission_id: mission_id,
      context: 'business_rules',
      details: details.merge(rule_name: rule_name)
    )
  end
  
  # Factory methods for business rule errors
  def self.client_company_required(mission_id = nil)
    new('client_company_required', { status: 'won' }, mission_id: mission_id)
  end
  
  def self.independent_company_required(mission_id = nil)
    new('independent_company_required', {}, mission_id: mission_id)
  end
  
  def self.start_date_required_for_in_progress(mission_id = nil)
    new('start_date_required', { status: 'in_progress' }, mission_id: mission_id)
  end
  
  def self.end_date_required_for_completed(mission_id = nil)
    new('end_date_required', { status: 'completed' }, mission_id: mission_id)
  end
  
  def self.financial_data_consistency(mission_type, daily_rate, fixed_price, mission_id = nil)
    new('financial_data_consistency', { 
      mission_type: mission_type, 
      daily_rate: daily_rate, 
      fixed_price: fixed_price 
    }, mission_id: mission_id)
  end
end
```

### MissionIntegrityError

```ruby
# Exception pour erreurs d'intégrité des données
class MissionIntegrityError < MissionErrors::MissionError
  def initialize(integrity_type, details = {}, mission_id = nil)
    super(
      "Erreur d'intégrité: #{integrity_type} (#{details})",
      mission_id: mission_id,
      context: 'data_integrity',
      details: details.merge(integrity_type: integrity_type)
    )
  end
  
  # Factory methods for integrity errors
  def self.cra_linked_deletion(mission_id = nil)
    new('cra_linked_deletion', { operation: 'delete' }, mission_id: mission_id)
  end
  
  def self.orphan_mission_company(mission_id, company_id)
    new('orphan_relation', { mission_id: mission_id, company_id: company_id }, mission_id: mission_id)
  end
  
  def self.multiple_independent_companies(mission_id, companies)
    new('multiple_independent_companies', { companies: companies }, mission_id: mission_id)
  end
end
```

---

## 🏢 CompanyErrors - Exceptions Company

### CompanyAccessError

```ruby
# Exception pour erreurs d'accès Company
class CompanyAccessError < MissionErrors::MissionError
  def initialize(access_type, user_id, company_id, reason = nil)
    super(
      "Accès Company #{access_type} refusé pour l'utilisateur #{user_id} sur la company #{company_id}#{": #{reason}" if reason}",
      context: 'company_access',
      details: { 
        access_type: access_type, 
        user_id: user_id, 
        company_id: company_id, 
        reason: reason 
      }
    )
  end
  
  # Factory methods for company access errors
  def self.insufficient_role(user_id, company_id, required_role, current_role)
    new('role_check', user_id, company_id, "required_#{required_role}_got_#{current_role}")
  end
  
  def self.company_not_found(user_id, company_id)
    new('existence', user_id, company_id, 'company_not_found')
  end
end
```

---

## 🔧 InfrastructureErrors - Exceptions Techniques

### DatabaseError

```ruby
# Exception pour erreurs base de données
class DatabaseError < MissionErrors::MissionError
  def initialize(operation, error, mission_id = nil)
    super(
      "Erreur base de données lors de #{operation}: #{error.message}",
      mission_id: mission_id,
      context: 'database',
      details: { 
        operation: operation, 
        database_error: error.class.name, 
        message: error.message 
      }
    )
  end
  
  # Factory methods for database errors
  def self.constraint_violation(operation, constraint, mission_id = nil)
    new(operation, "constraint_violation_#{constraint}", mission_id: mission_id)
  end
  
  def self.connection_failure(operation, mission_id = nil)
    new(operation, 'connection_failure', mission_id: mission_id)
  end
end
```

### ConcurrencyError

```ruby
# Exception pour erreurs de concurrence
class ConcurrencyError < MissionErrors::MissionError
  def initialize(operation, conflict_type, mission_id = nil)
    super(
      "Erreur de concurrence lors de #{operation}: #{conflict_type}",
      mission_id: mission_id,
      context: 'concurrency',
      details: { 
        operation: operation, 
        conflict_type: conflict_type 
      }
    )
  end
  
  # Factory methods for concurrency errors
  def self.stale_object(operation, mission_id = nil)
    new(operation, 'stale_object', mission_id: mission_id)
  end
  
  def self.lock_timeout(operation, mission_id = nil)
    new(operation, 'lock_timeout', mission_id: mission_id)
  end
end
```

---

## 🔄 Intégration avec les Lifecycle Guards

### MissionLifecycleService avec Exception Handling

```ruby
# app/services/mission_lifecycle_service.rb
class MissionLifecycleService
  def self.transition!(mission, new_status, user_id = nil)
    validate_preconditions!(mission, new_status, user_id)
    
    ActiveRecord::Base.transaction do
      mission.lock!
      
      execute_transition!(mission, new_status, user_id)
      mission.save!
      
      log_successful_transition(mission, new_status, user_id)
    rescue ActiveRecord::RecordInvalid => e
      raise MissionValidationError.new(
        e.record.class.name.underscore,
        e.record.attributes,
        e.message,
        mission_id: mission.id
      )
    rescue ActiveRecord::StaleObjectError
      raise ConcurrencyError.stale_object('lifecycle_transition', mission.id)
    end
    
    mission
  rescue => e
    log_failed_transition(mission, new_status, user_id, e)
    raise
  end
  
  private
  
  def self.validate_preconditions!(mission, new_status, user_id)
    # Validate transition authorization
    validate_authorization!(mission, user_id)
    
    # Validate transition rules
    validate_transition_rules!(mission, new_status)
    
    # Validate business prerequisites
    validate_business_prerequisites!(mission, new_status)
  end
  
  def self.validate_authorization!(mission, user_id)
    return if user_id.nil? || mission.created_by == user_id
    
    raise MissionAccessError.unauthorized_modify(user_id, mission.id)
  end
  
  def self.validate_transition_rules!(mission, new_status)
    unless can_transition?(mission.status, new_status)
      raise MissionLifecycleError.invalid_transition(
        mission.status, new_status, mission.id
      )
    end
  end
  
  def self.validate_business_prerequisites!(mission, new_status)
    case new_status
    when 'won'
      validate_won_prerequisites!(mission)
    when 'in_progress'
      validate_in_progress_prerequisites!(mission)
    when 'completed'
      validate_completed_prerequisites!(mission)
    end
  end
  
  def self.validate_won_prerequisites!(mission)
    unless mission.client_companies.any?
      raise MissionBusinessRuleError.client_company_required(mission.id)
    end
    
    mission.validate_financial_data_consistency
    if mission.errors.any?
      raise MissionValidationError.financial_data_inconsistent(
        mission.mission_type, mission.id
      )
    end
  end
  
  def self.validate_in_progress_prerequisites!(mission)
    unless mission.start_date
      raise MissionBusinessRuleError.start_date_required_for_in_progress(mission.id)
    end
    
    if mission.start_date > Date.today
      raise MissionValidationError.date_range_invalid(
        mission.start_date, Date.today, mission.id
      )
    end
  end
  
  def self.validate_completed_prerequisites!(mission)
    unless mission.status_was == 'in_progress'
      raise MissionLifecycleError.business_rule_violation(
        'completed', 'must_be_in_progress', mission.id
      )
    end
    
    unless mission.end_date
      raise MissionBusinessRuleError.end_date_required_for_completed(mission.id)
    end
    
    if mission.start_date && mission.end_date && mission.end_date < mission.start_date
      raise MissionValidationError.date_range_invalid(
        mission.start_date, mission.end_date, mission.id
      )
    end
  end
end
```

---

## 🌐 API Exception Handling

### Controller Exception Handling

```ruby
# app/controllers/api/v1/missions_controller.rb
class Api::V1::MissionsController < ApplicationController
  rescue_from MissionErrors::MissionError, with: :render_mission_error
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error
  
  def update
    mission = Mission.includes(:mission_companies, :companies).find(params[:id])
    
    validate_mission_access!(mission)
    validate_mission_modification!(mission)
    
    if params[:mission]&.[](:status)
      handle_lifecycle_transition(mission)
    else
      handle_mission_update(mission)
    end
  rescue MissionErrors::MissionAccessError => e
    render_mission_error(e)
  rescue MissionErrors::MissionLifecycleError => e
    render_mission_error(e)
  rescue MissionErrors::MissionValidationError => e
    render_mission_error(e)
  rescue ActiveRecord::StaleObjectError
    render json: { 
      error: 'concurrent_update', 
      message: 'La mission a été modifiée par un autre utilisateur' 
    }, status: :conflict
  end
  
  private
  
  def handle_lifecycle_transition(mission)
    new_status = params[:mission][:status]
    
    begin
      updated_mission = MissionLifecycleService.transition!(
        mission, 
        new_status, 
        current_user.id
      )
      
      render json: updated_mission, status: :ok
    rescue MissionErrors::MissionLifecycleError => e
      render json: { 
        error: 'lifecycle_transition_failed',
        message: e.message,
        current_status: mission.status,
        allowed_transitions: MissionLifecycleService::ALLOWED_TRANSITIONS[mission.status]
      }, status: :unprocessable_entity
    rescue MissionErrors::MissionBusinessRuleError => e
      render json: { 
        error: 'business_rule_violation',
        message: e.message,
        details: e.details
      }, status: :unprocessable_entity
    end
  end
  
  def render_mission_error(error)
    status_code = case error
    when MissionErrors::MissionAccessError then :forbidden
    when MissionErrors::MissionValidationError then :unprocessable_entity
    when MissionErrors::MissionLifecycleError then :unprocessable_entity
    when MissionErrors::MissionBusinessRuleError then :unprocessable_entity
    when MissionErrors::MissionIntegrityError then :conflict
    else :internal_server_error
    end
    
    render json: {
      error: error.class.name.demodulize.underscore,
      message: error.message,
      details: error.details,
      mission_id: error.mission_id,
      timestamp: Time.current.iso8601
    }, status: status_code
  end
  
  def render_validation_error(error)
    render json: {
      error: 'validation_failed',
      message: 'Données invalides',
      details: error.record.errors.full_messages,
      timestamp: Time.current.iso8601
    }, status: :unprocessable_entity
  end
  
  def render_not_found(error)
    render json: {
      error: 'resource_not_found',
      message: 'Mission non trouvée',
      timestamp: Time.current.iso8601
    }, status: :not_found
  end
end
```

### API Response Format Standardisé

```ruby
# lib/api_error_formatter.rb
module ApiErrorFormatter
  def self.format_error(error, request_id = nil)
    {
      error: error.respond_to?(:to_h) ? error.to_h : {
        error: error.class.name,
        message: error.message,
        details: error.details
      },
      request_id: request_id,
      timestamp: Time.current.iso8601
    }
  end
  
  def self.format_mission_error(error, mission_id = nil)
    {
      error: error.class.name.demodulize.underscore,
      message: error.message,
      mission_id: mission_id || error.mission_id,
      context: error.context,
      details: error.details,
      timestamp: Time.current.iso8601
    }
  end
end
```

---

## 🧪 Exception System Testing

### Exception Hierarchy Tests

```ruby
# spec/lib/mission_errors_spec.rb
RSpec.describe MissionErrors do
  describe MissionErrors::MissionError do
    it 'stores mission_id and context' do
      error = MissionErrors::MissionError.new(
        'Test message',
        mission_id: '123',
        context: 'test'
      )
      
      expect(error.mission_id).to eq('123')
      expect(error.context).to eq('test')
      expect(error.message).to eq('Test message')
    end
    
    it 'logs error on initialization' do
      expect(Rails.logger).to receive(:error)
      
      MissionErrors::MissionError.new('Test message')
    end
    
    it 'converts to hash' do
      error = MissionErrors::MissionError.new(
        'Test message',
        mission_id: '123',
        context: 'test',
        details: { foo: 'bar' }
      )
      
      hash = error.to_h
      expect(hash[:error]).to eq('mission_error')
      expect(hash[:message]).to eq('Test message')
      expect(hash[:mission_id]).to eq('123')
      expect(hash[:context]).to eq('test')
      expect(hash[:details][:foo]).to eq('bar')
    end
  end
  
  describe MissionValidationError do
    it 'creates validation error with field info' do
      error = MissionValidationError.new('name', nil, 'required', mission_id: '123')
      
      expect(error.message).to include('Validation échouée pour name')
      expect(error.mission_id).to eq('123')
      expect(error.details[:field]).to eq('name')
    end
    
    it 'provides factory methods' do
      error = MissionValidationError.mission_type_required('123')
      expect(error.message).to include('mission_type')
      expect(error.details[:rule]).to eq('required')
    end
  end
  
  describe MissionLifecycleError do
    it 'creates lifecycle error with status info' do
      error = MissionLifecycleError.new('lead', 'won', 'transition_not_allowed', mission_id: '123')
      
      expect(error.message).to include('lead → won')
      expect(error.details[:current_status]).to eq('lead')
      expect(error.details[:target_status]).to eq('won')
    end
  end
end
```

### Service Layer Exception Tests

```ruby
# spec/services/mission_lifecycle_service_exception_spec.rb
RSpec.describe MissionLifecycleService do
  describe '#transition!' do
    let(:mission) { create(:mission, status: 'lead') }
    let(:user) { create(:user) }
    
    context 'when user lacks authorization' do
      it 'raises MissionAccessError' do
        expect {
          MissionLifecycleService.transition!(mission, 'pending', user.id)
        }.to raise_error(MissionAccessError) do |error|
          expect(error.message).to include('Seul le créateur')
          expect(error.mission_id).to eq(mission.id)
        end
      end
    end
    
    context 'when transition is invalid' do
      before do
        mission.update!(created_by: user.id)
      end
      
      it 'raises MissionLifecycleError' do
        expect {
          MissionLifecycleService.transition!(mission, 'won', user.id)
        }.to raise_error(MissionBusinessRuleError) do |error|
          expect(error.message).to include('company client')
          expect(error.mission_id).to eq(mission.id)
        end
      end
    end
    
    context 'when concurrent update occurs' do
      before do
        mission.update!(created_by: user.id)
      end
      
      it 'raises ConcurrencyError' do
        mission1 = Mission.find(mission.id)
        mission2 = Mission.find(mission.id)
        
        mission1.update!(name: "Updated Name 1")
        
        expect {
          mission2.update!(name: "Updated Name 2")
        }.to raise_error(ConcurrencyError)
      end
    end
  end
end
```

### API Exception Handling Tests

```ruby
# spec/requests/api/v1/missions_exception_spec.rb
RSpec.describe 'Api::V1::Missions Exceptions', type: :request do
  describe 'Lifecycle Transition Errors' do
    let(:mission) { create(:mission, status: 'lead', created_by: user.id) }
    
    context 'when transition is invalid' do
      it 'returns lifecycle error response' do
        patch "/api/v1/missions/#{mission.id}",
              params: { mission: { status: 'won' } }.to_json,
              headers: auth_headers(user)
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        
        expect(json_response['error']).to eq('mission_business_rule_error')
        expect(json_response['message']).to include('company client')
        expect(json_response['mission_id']).to eq(mission.id)
      end
    end
    
    context 'when user lacks modification rights' do
      let(:other_user) { create(:user) }
      
      it 'returns access error response' do
        patch "/api/v1/missions/#{mission.id}",
              params: { mission: { status: 'pending' } }.to_json,
              headers: auth_headers(other_user)
        
        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        
        expect(json_response['error']).to eq('mission_access_error')
        expect(json_response['message']).to include('Seul le créateur')
      end
    end
    
    context 'when mission does not exist' do
      it 'returns not found response' do
        patch "/api/v1/missions/non-existent-id",
              params: { mission: { status: 'pending' } }.to_json,
              headers: auth_headers(user)
        
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        
        expect(json_response['error']).to eq('resource_not_found')
        expect(json_response['message']).to include('Mission non trouvée')
      end
    end
  end
end
```

---

## 📊 Exception Monitoring et Logging

### Exception Tracking

```ruby
# lib/mission_exception_tracker.rb
class MissionExceptionTracker
  def self.track_exception(error, context = {})
    Rails.logger.error({
      event: 'mission_exception',
      error_class: error.class.name,
      error_message: error.message,
      mission_id: error.respond_to?(:mission_id) ? error.mission_id : nil,
      context: context,
      user_id: context[:user_id],
      timestamp: Time.current.iso8601,
      request_id: context[:request_id]
    }.to_json)
    
    # Send to monitoring service (e.g., Datadog, Sentry)
    send_to_monitoring(error, context)
  end
  
  def self.track_business_rule_violation(rule_name, mission_id, details = {})
    Rails.logger.warn({
      event: 'business_rule_violation',
      rule_name: rule_name,
      mission_id: mission_id,
      details: details,
      timestamp: Time.current.iso8601
    }.to_json)
  end
  
  def self.track_lifecycle_transition_failure(mission_id, from_status, to_status, error)
    Rails.logger.error({
      event: 'lifecycle_transition_failure',
      mission_id: mission_id,
      from_status: from_status,
      to_status: to_status,
      error_class: error.class.name,
      error_message: error.message,
      timestamp: Time.current.iso8601
    }.to_json)
  end
  
  private
  
  def self.send_to_monitoring(error, context)
    # Implementation for monitoring service
    # Example for Datadog:
    # Datadog::Tracer.active_span.set_tag('error', true)
    # Datadog::Tracer.active_span.set_tag('error.type', error.class.name)
    # Datadog::Tracer.active_span.set_tag('error.msg', error.message)
  end
end
```

### Exception Metrics

```ruby
# lib/mission_exception_metrics.rb
class MissionExceptionMetrics
  def self.increment_validation_error(field, mission_type = nil)
    Rails.logger.info({
      event: 'metric',
      name: 'mission.validation_error',
      field: field,
      mission_type: mission_type,
      timestamp: Time.current.iso8601
    }.to_json)
  end
  
  def self.increment_lifecycle_error(from_status, to_status, error_type)
    Rails.logger.info({
      event: 'metric',
      name: 'mission.lifecycle_error',
      from_status: from_status,
      to_status: to_status,
      error_type: error_type,
      timestamp: Time.current.iso8601
    }.to_json)
  end
  
  def self.increment_access_error(access_type, reason)
    Rails.logger.info({
      event: 'metric',
      name: 'mission.access_error',
      access_type: access_type,
      reason: reason,
      timestamp: Time.current.iso8601
    }.to_json)
  end
end
```

---

## 🎯 Best Practices pour les Exceptions

### 1. Exception Design Principles

```ruby
# Good: Specific, meaningful exceptions
def validate_mission_type(mission_type)
  unless ['time_based', 'fixed_price'].include?(mission_type)
    raise MissionValidationError.new(
      'mission_type', mission_type, 'inclusion', mission_id: nil
    )
  end
end

# Bad: Generic exceptions
def validate_mission_type(mission_type)
  raise "Invalid mission type" unless ['time_based', 'fixed_price'].include?(mission_type)
end
```

### 2. Context-Rich Error Messages

```ruby
# Good: Rich context in exceptions
def transition_to_won(mission)
  unless mission.client_companies.any?
    raise MissionBusinessRuleError.client_company_required(mission.id)
  end
end

# Bad: Poor context
def transition_to_won(mission)
  raise "Client company required" unless mission.client_companies.any?
end
```

### 3. Proper Exception Hierarchy

```ruby
# Good: Proper inheritance
class MissionLifecycleError < MissionErrors::MissionError; end
class InvalidTransitionError < MissionLifecycleError; end

# Bad: Flat exception structure
class MissionError < StandardError; end
class InvalidTransitionError < StandardError; end
```

### 4. Logging et Monitoring

```ruby
# Good: Structured logging
def execute_transition(mission, new_status)
  Rails.logger.info({
    event: 'lifecycle_transition',
    mission_id: mission.id,
    from_status: mission.status,
    to_status: new_status,
    user_id: current_user.id
  }.to_json)
rescue => error
  Rails.logger.error({
    event: 'lifecycle_transition_failed',
    mission_id: mission.id,
    error_class: error.class.name,
    error_message: error.message
  }.to_json)
  raise
end
```

---

## 📚 Références et Documentation

### Code References
- **[MissionErrors Module](../../lib/mission_errors.rb)** : Exception hierarchy implementation
- **[MissionLifecycleService](../../app/services/mission_lifecycle_service.rb)** : Service with exception handling
- **[MissionsController](../../app/controllers/api/v1/missions_controller.rb)** : API exception handling
- **[Lifecycle Guards Details](./lifecycle_guards_details.md)** : Guards integration with exceptions

### Documentation Links
- **[DDD Architecture Principles](../methodology/ddd_architecture_principles.md)** : Architecture context
- **[Test Coverage Report](../testing/test_coverage_report.md)** : Exception testing coverage
- **[FC06 Implementation](../changes/2025-12-31-FC06_Missions_Implementation.md)** : Full implementation

### Exception Categories
- **MissionValidationError** : Data validation failures
- **MissionLifecycleError** : State transition failures
- **MissionAccessError** : Authorization failures
- **MissionBusinessRuleError** : Business rule violations
- **MissionIntegrityError** : Data integrity violations

---

## 🏷️ Tags et Classification

### Exception Types
- **Business Logic** : Mission-specific business errors
- **Validation** : Data validation errors
- **Access Control** : Authorization errors
- **Infrastructure** : Technical errors
- **Concurrency** : Multi-user conflicts

### Error Severity
- **Critical** : System integrity compromised
- **Major** : Business function unavailable
- **Minor** : Feature degradation
- **Warning** : Non-blocking issues

### Error Sources
- **User Input** : Validation errors
- **Business Logic** : Rule violations
- **System** : Technical failures
- **External** : Third-party dependencies

---

*Cette documentation détaille le système d'exceptions complet et hiérarchisé de FC06*  
*Dernière mise à jour : 31 Décembre 2025 - Système d'exceptions validé et opérationnel*  
*Pattern réplicable pour toutes les futures features du projet*