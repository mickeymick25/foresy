# frozen_string_literal: true

# 🔴 P5.1 + P5.2 + P5.4 — Base de Données & Configuration
#
# P5.1: users.uuid et sessions.uuid doivent être de type UUID natif PostgreSQL
# P5.2: user_missions.role et user_cras.role doivent utiliser un enum PostgreSQL
# P5.4: config.load_defaults doit être aligné sur Rails 8.x

require 'rails_helper'

RSpec.describe 'P5.1 + P5.2 + P5.4 — DB & Config' do
  describe 'P5.1 — UUID natif PostgreSQL' do
    it 'users.uuid is a UUID type column (not string)' do
      column = User.columns_hash['uuid']
      expect(column.sql_type).to eq('uuid')
    end

    it 'sessions.uuid is a UUID type column (not string)' do
      column = Session.columns_hash['uuid']
      expect(column.sql_type).to eq('uuid')
    end
  end

  describe 'P5.2 — Enum PostgreSQL pour user_missions.role et user_cras.role' do
    it 'user_missions.role uses a PostgreSQL enum type' do
      column = UserMission.columns_hash['role']
      expect(column.sql_type).to eq('user_relation_role')
    end

    it 'user_cras.role uses a PostgreSQL enum type' do
      column = UserCra.columns_hash['role']
      expect(column.sql_type).to eq('user_relation_role')
    end

    it 'UserMission can be created with role creator' do
      user = create(:user)
      mission = create(:mission, :with_creator, creator: user)
      um = UserMission.where(user: user, mission: mission).first
      expect(um.role).to eq('creator')
    end
  end

  describe 'P5.4 — config.load_defaults aligned on Rails 8.x' do
    it 'load_defaults is >= 8.0 in config/application.rb' do
      content = File.read(Rails.root.join('config/application.rb'))
      expect(content).to match(/config\.load_defaults\s+8\.\d+/)
    end
  end
end
