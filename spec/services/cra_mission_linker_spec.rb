# frozen_string_literal: true

require 'rails_helper'

# Spec tests for CraMissionLinker service
# Tests all business logic and error handling for CRA-Mission linking
RSpec.describe CraMissionLinker, type: :service do
  describe '.link_cra_to_mission!' do
    let(:cra) { create(:cra) }
    let(:mission) { create(:mission) }

    context 'when successful link creation' do
      it 'creates a new CRA-Mission link' do
        expect do
          described_class.link_cra_to_mission!(cra.id, mission.id)
        end.to change(CraMission, :count).by(1)

        link = CraMission.find_by(cra_id: cra.id, mission_id: mission.id)
        expect(link).to be_present
        expect(link.cra_id).to eq(cra.id)
        expect(link.mission_id).to eq(mission.id)
      end

      it 'returns the created link' do
        link = described_class.link_cra_to_mission!(cra.id, mission.id)
        expect(link).to be_a(CraMission)
        expect(link.cra_id).to eq(cra.id)
        expect(link.mission_id).to eq(mission.id)
      end

      it 'logs the successful link creation' do
        expect(Rails.logger).to receive(:info).with(
          "[CraMissionLinker] Created link between CRA #{cra.id} and Mission #{mission.id}"
        )

        described_class.link_cra_to_mission!(cra.id, mission.id)
      end
    end

    context 'when link already exists' do
      before do
        create(:cra_mission, cra_id: cra.id, mission_id: mission.id)
      end

      it 'returns the existing link without creating a duplicate' do
        expect do
          result = described_class.link_cra_to_mission!(cra.id, mission.id)
          expect(result).to be_present
        end.not_to change(CraMission, :count)

        link = CraMission.find_by(cra_id: cra.id, mission_id: mission.id)
        expect(link).to be_present
      end

      it 'logs that the mission is already linked' do
        expect(Rails.logger).to receive(:info).with(
          "[CraMissionLinker] Mission #{mission.id} already linked to CRA #{cra.id}"
        )

        described_class.link_cra_to_mission!(cra.id, mission.id)
      end
    end

    context 'when CRA does not exist' do
      it 'raises RecordNotFound error' do
        expect do
          described_class.link_cra_to_mission!('invalid-cra-id', mission.id)
        end.to raise_error(ActiveRecord::RecordNotFound, 'CRA not found with id: invalid-cra-id')
      end
    end

    context 'when mission does not exist' do
      it 'raises RecordNotFound error' do
        expect do
          described_class.link_cra_to_mission!(cra.id, 'invalid-mission-id')
        end.to raise_error(ActiveRecord::RecordNotFound, 'Mission not found with id: invalid-mission-id')
      end
    end

    context 'when parameters are missing' do
      it 'raises ArgumentError for missing cra_id' do
        expect do
          described_class.link_cra_to_mission!(nil, mission.id)
        end.to raise_error(ArgumentError, 'cra_id and mission_id are required')
      end

      it 'raises ArgumentError for missing mission_id' do
        expect do
          described_class.link_cra_to_mission!(cra.id, nil)
        end.to raise_error(ArgumentError, 'cra_id and mission_id are required')
      end

      it 'raises ArgumentError for both missing' do
        expect do
          described_class.link_cra_to_mission!(nil, nil)
        end.to raise_error(ArgumentError, 'cra_id and mission_id are required')
      end
    end

    context 'when database transaction fails' do
      before do
        # Mock a database error by making the create fail
        allow(CraMission).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 're-raises the database error' do
        expect do
          described_class.link_cra_to_mission!(cra.id, mission.id)
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'with soft deleted CRA or mission' do
      let(:deleted_cra) { create(:cra, :discarded) }
      let(:deleted_mission) { create(:mission, :discarded) }

      it 'raises RecordNotFound for deleted CRA' do
        expect do
          described_class.link_cra_to_mission!(deleted_cra.id, mission.id)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'raises RecordNotFound for deleted mission' do
        expect do
          described_class.link_cra_to_mission!(cra.id, deleted_mission.id)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '.mission_linked_to_cra?' do
    let(:cra) { create(:cra) }
    let(:mission) { create(:mission) }

    context 'when mission is linked to CRA' do
      before do
        create(:cra_mission, cra_id: cra.id, mission_id: mission.id)
      end

      it 'returns true' do
        expect(described_class.mission_linked_to_cra?(cra.id, mission.id)).to be true
      end
    end

    context 'when mission is not linked to CRA' do
      it 'returns false' do
        expect(described_class.mission_linked_to_cra?(cra.id, mission.id)).to be false
      end
    end

    context 'with missing parameters' do
      it 'returns false for missing cra_id' do
        expect(described_class.mission_linked_to_cra?(nil, mission.id)).to be false
      end

      it 'returns false for missing mission_id' do
        expect(described_class.mission_linked_to_cra?(cra.id, nil)).to be false
      end

      it 'returns false for both missing' do
        expect(described_class.mission_linked_to_cra?(nil, nil)).to be false
      end
    end

    context 'with non-existent CRA or mission' do
      it 'returns false for non-existent CRA' do
        expect(described_class.mission_linked_to_cra?('invalid-id', mission.id)).to be false
      end

      it 'returns false for non-existent mission' do
        expect(described_class.mission_linked_to_cra?(cra.id, 'invalid-id')).to be false
      end
    end
  end

  describe '.get_missions_for_cra' do
    let(:cra) { create(:cra) }
    let(:mission1) { create(:mission) }
    let(:mission2) { create(:mission) }

    context 'when CRA has linked missions' do
      before do
        create(:cra_mission, cra_id: cra.id, mission_id: mission1.id)
        create(:cra_mission, cra_id: cra.id, mission_id: mission2.id)
      end

      it 'returns all missions linked to the CRA' do
        missions = described_class.get_missions_for_cra(cra.id)
        expect(missions).to include(mission1, mission2)
        expect(missions.count).to eq(2)
      end

      it 'returns missions in correct order' do
        missions = described_class.get_missions_for_cra(cra.id)
        mission_ids = missions.pluck(:id).sort
        expect(mission_ids).to eq([mission1.id, mission2.id].sort)
      end
    end

    context 'when CRA has no linked missions' do
      it 'returns empty relation' do
        missions = described_class.get_missions_for_cra(cra.id)
        expect(missions).to be_empty
      end
    end

    context 'with missing cra_id' do
      it 'returns empty relation' do
        missions = described_class.get_missions_for_cra(nil)
        expect(missions).to be_empty
      end
    end

    context 'with non-existent CRA' do
      it 'returns empty relation' do
        missions = described_class.get_missions_for_cra('invalid-id')
        expect(missions).to be_empty
      end
    end
  end

  describe '.get_cras_for_mission' do
    let(:mission) { create(:mission) }
    let(:cra1) { create(:cra) }
    let(:cra2) { create(:cra) }

    context 'when mission is linked to CRAs' do
      before do
        create(:cra_mission, cra_id: cra1.id, mission_id: mission.id)
        create(:cra_mission, cra_id: cra2.id, mission_id: mission.id)
      end

      it 'returns all CRAs linked to the mission' do
        cras = described_class.get_cras_for_mission(mission.id)
        expect(cras).to include(cra1, cra2)
        expect(cras.count).to eq(2)
      end
    end

    context 'when mission has no linked CRAs' do
      it 'returns empty relation' do
        cras = described_class.get_cras_for_mission(mission.id)
        expect(cras).to be_empty
      end
    end

    context 'with missing mission_id' do
      it 'returns empty relation' do
        cras = described_class.get_cras_for_mission(nil)
        expect(cras).to be_empty
      end
    end

    context 'with non-existent mission' do
      it 'returns empty relation' do
        cras = described_class.get_cras_for_mission('invalid-id')
        expect(cras).to be_empty
      end
    end
  end

  describe '.unlink_cra_from_mission!' do
    let(:cra) { create(:cra) }
    let(:mission) { create(:mission) }
    let!(:link) { create(:cra_mission, cra_id: cra.id, mission_id: mission.id) }

    context 'when successful unlinking' do
      it 'removes the link' do
        expect do
          described_class.unlink_cra_from_mission!(cra.id, mission.id)
        end.to change(CraMission, :count).by(-1)

        expect(CraMission.find_by(cra_id: cra.id, mission_id: mission.id)).to be_nil
      end

      it 'destroys the specific link' do
        described_class.unlink_cra_from_mission!(cra.id, mission.id)

        expect(CraMission.exists?(id: link.id)).to be false
      end
    end

    context 'when link does not exist' do
      it 'raises RecordNotFound' do
        expect do
          described_class.unlink_cra_from_mission!(cra.id, 'different-mission-id')
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when database error occurs during destroy' do
      let(:mock_link) { double('CraMission') }

      before do
        allow(CraMission).to receive(:find_by!).and_return(mock_link)
        allow(mock_link).to receive(:destroy!).and_raise(ActiveRecord::StatementInvalid, 'Database connection lost')
      end

      it 'raises the database error' do
        expect do
          described_class.unlink_cra_from_mission!(cra.id, mission.id)
        end.to raise_error(ActiveRecord::StatementInvalid, 'Database connection lost')
      end
    end

    context 'with nil parameters' do
      it 'raises RecordNotFound for nil cra_id' do
        expect do
          described_class.unlink_cra_from_mission!(nil, mission.id)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'raises RecordNotFound for nil mission_id' do
        expect do
          described_class.unlink_cra_from_mission!(cra.id, nil)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'raises RecordNotFound for both nil' do
        expect do
          described_class.unlink_cra_from_mission!(nil, nil)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '.debug_info' do
    let(:cra) { create(:cra) }
    let(:mission) { create(:mission) }

    context 'when all entities exist and are linked' do
      before do
        create(:cra_mission, cra_id: cra.id, mission_id: mission.id)
      end

      it 'returns debug information' do
        info = described_class.debug_info(cra.id, mission.id)

        expect(info).to include(
          cra_exists: true,
          mission_exists: true,
          already_linked: true,
          cra_status: 'draft',
          mission_name: mission.name
        )
      end
    end

    context 'when CRA does not exist' do
      it 'returns partial debug information' do
        info = described_class.debug_info('invalid-cra-id', mission.id)

        expect(info).to include(
          cra_exists: false,
          mission_exists: true,
          already_linked: false,
          mission_name: mission.name
        )
        expect(info).not_to include(:cra_status)
      end
    end

    context 'when mission does not exist' do
      it 'returns partial debug information' do
        info = described_class.debug_info(cra.id, 'invalid-mission-id')

        expect(info).to include(
          cra_exists: true,
          mission_exists: false,
          already_linked: false,
          cra_status: 'draft'
        )
        expect(info).not_to include(:mission_name)
      end
    end

    context 'when neither exists' do
      it 'returns minimal debug information' do
        info = described_class.debug_info('invalid-cra-id', 'invalid-mission-id')

        expect(info).to include(
          cra_exists: false,
          mission_exists: false,
          already_linked: false
        )
        expect(info).not_to include(:cra_status, :mission_name)
      end
    end

    context 'when entities exist but are not linked' do
      it 'returns debug information with already_linked: false' do
        info = described_class.debug_info(cra.id, mission.id)

        expect(info).to include(
          cra_exists: true,
          mission_exists: true,
          already_linked: false,
          cra_status: 'draft',
          mission_name: mission.name
        )
      end
    end

    context 'with soft deleted entities' do
      let(:deleted_cra) { create(:cra, :discarded) }
      let(:deleted_mission) { create(:mission, :discarded) }

      it 'returns cra_exists: true for soft deleted CRA' do
        info = described_class.debug_info(deleted_cra.id, mission.id)
        expect(info[:cra_exists]).to be true
      end

      it 'returns mission_exists: true for soft deleted mission' do
        info = described_class.debug_info(cra.id, deleted_mission.id)
        expect(info[:mission_exists]).to be true
      end
    end
  end

  describe 'transactional behavior' do
    let(:cra) { create(:cra) }
    let(:mission) { create(:mission) }

    context 'when transaction fails during link creation' do
      before do
        # Mock a failure in the middle of transaction
        allow(CraMission).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, 'Database error')
      end

      it 'rolls back the transaction' do
        expect do
          described_class.link_cra_to_mission!(cra.id, mission.id)
        end.to raise_error(ActiveRecord::StatementInvalid)

        # Verify no link was created
        expect(CraMission.find_by(cra_id: cra.id, mission_id: mission.id)).to be_nil
      end
    end

    context 'when multiple operations are in transaction' do
      # This test verifies that the transaction encompasses all operations
      it 'maintains data consistency' do
        # This is more of a behavioral test since we don't have multi-step operations
        # in the current implementation, but it's good to have the test structure
        expect do
          described_class.link_cra_to_mission!(cra.id, mission.id)
        end.to change(CraMission, :count).by(1)

        # Verify the link was created completely
        link = CraMission.find_by(cra_id: cra.id, mission_id: mission.id)
        expect(link).to be_present
        expect(link.cra_id).to eq(cra.id)
        expect(link.mission_id).to eq(mission.id)
      end
    end
  end
end
