# frozen_string_literal: true

require 'rails_helper'

# W3-D4 — Contrats des pivots (P6 Wave 3)
#
# UserCra / UserMission : méthodes de rôle + finders de créateur.
# CraMission / CraEntryCra / CraEntryMission : display_link + gardes
# d'unicité de lien. MissionCompany : exclusivité independent/client.
RSpec.describe UserCra, type: :model do
  let(:cra) { create(:cra, :with_creator, creator: create(:user), year: 2026, month: 9) }
  let(:creator_pivot) { described_class.cra_creator(cra.id) }

  it 'expose les méthodes de rôle' do
    expect(creator_pivot.creator?).to be(true)
    expect(creator_pivot.contributor?).to be(false)
    expect(creator_pivot.reviewer?).to be(false)
  end

  it 'cra_creator retourne le pivot créateur du CRA' do
    expect(creator_pivot.cra_id).to eq(cra.id)
  end

  it 'user_created_cras retourne les CRAs créés par l utilisateur' do
    found = described_class.user_created_cras(creator_pivot.user_id)

    expect(found).to include(creator_pivot)
  end
end

RSpec.describe UserMission, type: :model do
  let(:mission) { create(:mission, :time_based, :with_creator, creator: create(:user)) }
  let(:creator_pivot) { described_class.mission_creator(mission.id) }

  it 'expose les méthodes de rôle' do
    expect(creator_pivot.creator?).to be(true)
    expect(creator_pivot.contributor?).to be(false)
    expect(creator_pivot.reviewer?).to be(false)
  end

  it 'mission_creator retourne le pivot créateur de la mission' do
    expect(creator_pivot.mission_id).to eq(mission.id)
  end

  it 'user_created_missions retourne les missions créées par l utilisateur' do
    expect(described_class.user_created_missions(creator_pivot.user_id)).to include(creator_pivot)
  end
end

RSpec.describe CraMission, type: :model do
  it 'display_link expose la liaison CRA ↔ Mission' do
    link = create(:cra_mission, cra: create(:cra, :with_creator, creator: create(:user)),
                                mission: create(:mission, :time_based, :with_creator,
                                                creator: create(:user)))

    expect(link.display_link).to eq("CRA #{link.cra_id} ↔ Mission #{link.mission_id}")
  end

  it 'refuse un lien CRA ↔ Mission dupliqué (garde métier)' do
    creator = create(:user)
    cra = create(:cra, :with_creator, creator: creator)
    mission = create(:mission, :time_based, :with_creator, creator: creator)
    create(:cra_mission, cra: cra, mission: mission)

    duplicate = build(:cra_mission, cra: cra, mission: mission)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:mission_id]).to be_present
  end
end

RSpec.describe CraEntryCra, type: :model do
  it 'caractérise le lien entry ↔ CRA (branches restantes)' do
    creator = create(:user)
    cra = create(:cra, :with_creator, creator: creator)
    entry = create(:cra_entry, cra: cra, date: Date.new(2026, 9, 5))
    link = described_class.find_by(cra_entry_id: entry.id)

    expect(link).to be_present
    expect(link.cra_id).to eq(cra.id)
  end
end

RSpec.describe CraEntryMission, type: :model do
  it 'display_link / cra / entry_date exposent la liaison' do
    creator = create(:user)
    cra = create(:cra, :with_creator, creator: creator)
    mission = create(:mission, :time_based, :with_creator, creator: creator)
    entry = create(:cra_entry, cra: cra, mission: mission, date: Date.new(2026, 9, 5))
    link = described_class.find_by(cra_entry_id: entry.id)

    expect(link.display_link).to eq("CRAEntry #{entry.id} ↔ Mission #{mission.id}")
    expect(link.cra).to eq(cra)
    expect(link.entry_date).to eq(Date.new(2026, 9, 5))
  end

  it 'refuse un lien CRAEntry ↔ Mission dupliqué (garde métier)' do
    creator = create(:user)
    cra = create(:cra, :with_creator, creator: creator)
    mission = create(:mission, :time_based, :with_creator, creator: creator)
    entry = create(:cra_entry, cra: cra, mission: mission, date: Date.new(2026, 9, 5))
    link = described_class.find_by(cra_entry_id: entry.id)

    duplicate = build(:cra_entry_mission, cra_entry_id: entry.id, mission_id: mission.id)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:mission_id]).to include('already_linked')
    link
  end
end

RSpec.describe MissionCompany, type: :model do
  let(:creator) { create(:user) }
  let(:mission) { create(:mission, :time_based, :with_creator, creator: creator) }

  it 'independent? / client? / display_role reflètent le rôle' do
    company = create(:company)
    link = create(:mission_company, mission: mission, company: company, role: 'independent')

    expect(link.independent?).to be(true)
    expect(link.client?).to be(false)
    expect(link.display_role).to eq('Independent')
  end

  it 'rejette un second lien independent pour la même mission (exclusivité FC-08)' do
    create(:mission_company, mission: mission, company: create(:company), role: 'independent')

    duplicate = build(:mission_company, mission: mission, company: create(:company), role: 'independent')

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:role]).to include('mission_already_has_independent')
  end

  it 'rejette un second lien client pour la même mission (exclusivité FC-08)' do
    create(:mission_company, mission: mission, company: create(:company), role: 'client')

    duplicate = build(:mission_company, mission: mission, company: create(:company), role: 'client')

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:role]).to include('mission_already_has_client')
  end

  it 'tolère plusieurs rôles non-exclusifs (ex. contributor)' do
    create(:mission_company, mission: mission, company: create(:company), role: 'independent')

    second = build(:mission_company, mission: mission, company: create(:company), role: 'client')

    expect(second).to be_valid
  end
end
