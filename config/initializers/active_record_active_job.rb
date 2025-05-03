# frozen_string_literal: true

# config/initializers/active_record_active_job.rb

Rails.application.configure do
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.active_job.verbose_enqueue_logs = true
end
