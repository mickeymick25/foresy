# frozen_string_literal: true

# ApplicationMailer
#
# Contains mailer methods available across views.
class ApplicationMailer < ActionMailer::Base
  default from: 'from@example.com'
  layout 'mailer'
end
