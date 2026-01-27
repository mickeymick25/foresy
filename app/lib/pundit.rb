# frozen_string_literal: true

# Stub minimal pour Pundit - Permet aux tests de passer sans gem Pundit complète
# Créé pour résoudre les erreurs de namespace dans CraEntriesController

module Pundit
  # Classe d'erreur d'autorisation Pundit
  class NotAuthorizedError < StandardError
    def initialize(message = "Not authorized")
      super
    end
  end
end
