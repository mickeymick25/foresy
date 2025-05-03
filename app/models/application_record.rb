# frozen_string_literal: true

# ApplicationRecord
#
# Abstract base class for all ActiveRecord models.
# Inherits from ActiveRecord::Base and includes application-wide model behavior.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
