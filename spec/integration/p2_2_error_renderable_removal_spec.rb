# frozen_string_literal: true

# 🔴 P2.2 — Unification Erreurs : suppression du concern orphelin ErrorRenderable
#
# This spec characterizes the fix for audit point C1
# (see docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md).
#
# ErrorRenderable is a concern that defines a different error format
# ({ error: { code, message, details } }) but is NEVER included in
# any controller. It's dead code that creates confusion with the
# standardized StandardizedError concern.
#
# Invariant: ErrorRenderable must NOT be autoloadable after cleanup.

require 'rails_helper'

RSpec.describe 'P2.2 — ErrorRenderable orphan concern removal' do
  it 'does not autoload ErrorRenderable' do
    expect(defined?(ErrorRenderable)).to be_nil
  end

  it 'does not have the file in app/controllers/concerns' do
    path = Rails.root.join('app/controllers/concerns/error_renderable.rb')
    expect(File.exist?(path)).to be(false)
  end
end
