# frozen_string_literal: true

# W1-D2-BUG — détermination (point de vigilance CTO) : `Mission.accessible_to`
# présente-t-il le même défaut de propagation du soft-delete, dans un appel
# fonctionnel ? OBSERVATION SEULE — aucune correction préventive spéculative
# (arbitrage CTO 18/09 : caractériser uniquement ce qui est nécessaire au bug
# identifié, puis déterminer).
#
# Chaîne via-companies de Mission : mission_companies → user_companies.
# Le pivot mission_companies ne porte pas de soft delete (hard delete, schéma) —
# la seule frontière analogue au bug CRA est user_companies.deleted_at (FC-08).
require 'rails_helper'

RSpec.describe 'Mission.accessible_to', type: :model do
  let(:member) { create(:user) }
  let(:member_company) { create(:company) }
  let(:creator) { create(:user) }
  let(:mission) { create(:mission, :time_based, :with_creator, creator: creator) }

  before do
    create(:user_company, user: member, company: member_company, role: 'independent')
    create(:mission_company, mission: mission, company: member_company, role: 'independent')
  end

  it 'voie companies : inclut la mission pour un membre lié (témoin positif)' do
    expect(Mission.accessible_to(member)).to include(mission)
  end

  it 'OBSERVATION : une adhésion révoquée (user_company soft-deleté — FC-08) ' \
     'continue d octroyer l accès à la mission' do
    member.user_companies.update_all(deleted_at: Time.current)

    expect(Mission.accessible_to(member)).to include(mission)
  end
end
