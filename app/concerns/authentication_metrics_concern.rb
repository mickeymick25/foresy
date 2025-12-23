# frozen_string_literal: true

# AuthenticationMetricsConcern
#
# Concern providing APM metrics methods for authentication services.
# Extracted from AuthenticationMetricsConcern to reduce module length.
#
module AuthenticationMetricsConcern
  extend ActiveSupport::Concern

  class_methods do
    def record_login_metrics(user, session, duration)
      return unless defined?(NewRelic)

      NewRelic::Agent.add_custom_attributes({
                                              auth_operation: 'login',
                                              auth_duration_ms: (duration * 1000).round(2),
                                              user_id: user.id,
                                              session_id: session.id
                                            })
    end

    def record_login_error_metrics(error)
      return unless defined?(NewRelic)

      NewRelic::Agent.add_custom_attributes({
                                              auth_operation: 'login',
                                              auth_error_type: error.class.name,
                                              auth_error_message: error.message
                                            })
    end

    def record_refresh_metrics(user, session, duration)
      return unless defined?(NewRelic)

      NewRelic::Agent.add_custom_attributes({
                                              auth_operation: 'refresh',
                                              auth_duration_ms: (duration * 1000).round(2),
                                              user_id: user.id,
                                              session_id: session.id
                                            })
    end

    def record_refresh_error_metrics(error)
      return unless defined?(NewRelic)

      NewRelic::Agent.add_custom_attributes({
                                              auth_operation: 'refresh',
                                              auth_error_type: error.class.name,
                                              auth_error_message: error.message
                                            })
    end
  end
end
