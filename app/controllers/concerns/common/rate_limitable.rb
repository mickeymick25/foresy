# frozen_string_literal: true

module Common
  # Extrait l'IP client pour le rate limiting (Authentication, Users, Missions).
  #
  # R-4 (contrat FC-05 v1) : le mécanisme de rate limiting vit désormais
  # exclusivement dans `RateLimitService` (+ backends `RateLimit::*`). L'ancien
  # limiter parallèle (`Common::RedisRateLimiter` — compteur jamais incrémenté)
  # a été supprimé ; ce concern ne conserve que l'extraction d'IP.
  module RateLimitable
    extend ActiveSupport::Concern

    private

    # Shared method for extracting client IP from request headers.
    # Used by AuthenticationController, UsersController and MissionsController.
    def extract_client_ip_for_rate_limiting
      forwarded_for = request.env['HTTP_X_FORWARDED_FOR']
      if forwarded_for.present?
        forwarded_for.split(',').first.strip
      else
        request.env['HTTP_X_REAL_IP'] || request.env['REMOTE_ADDR'] || 'unknown'
      end
    end
  end
end
