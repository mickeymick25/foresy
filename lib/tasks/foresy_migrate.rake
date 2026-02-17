# frozen_string_literal: true

# frozen_string_literal: true

# Rake Task: Foresy Migration - Backfill and Verification
# Part of DDD Relation-Driven Correction (PLATINUM)
#
# Purpose: Backfill historical data from created_by_user_id to pivot tables
#         and verify data integrity before constraints are added.
#
# Order of execution (after Phase A migrations):
# 1. Run: rake foresy:migrate:backfill_missions
# 2. Run: rake foresy:migrate:backfill_cras
# 3. Run: rake foresy:migrate:verify_integrity
#
# IMPORTANT: This task is IDEMPOTENT - safe to re-run
# Uses find_or_create_by! to prevent RecordNotUnique errors
#
# @see docs/technical/corrections/2026-02-15-DDD_Relation-Driven_Correction.md

namespace :foresy do
  namespace :migrate do
    desc "PHASE 1: Backfill user_missions from historical missions (IDEMPOTENT)"
    task backfill_missions: :environment do
      puts "=" * 60
      puts "🔄 PHASE 1: Backfilling user_missions from historical data"
      puts "=" * 60

      migrated = 0
      skipped = 0
      errors = []

      Mission.find_each do |mission|
        # Skip missions without creator
        if mission.created_by_user_id.nil?
          skipped += 1
          next
        end

        # IDEMPOTENT: Use find_or_create_by! to allow re-running
        user_mission = UserMission.find_or_create_by!(
          mission_id: mission.id,
          role: "creator"
        ) do |um|
          um.user_id = mission.created_by_user_id
          um.created_at = mission.created_at || Time.current
        end

        migrated += 1 if user_mission.persisted?
      rescue ActiveRecord::RecordNotUnique => e
        errors << "RecordNotUnique for mission #{mission.id}: #{e.message}"
      rescue StandardError => e
        errors << "Error for mission #{mission.id}: #{e.message}"
      end

      puts ""
      puts "✅ #{migrated} user_missions created or verified"
      puts "⚠️  #{skipped} missions without creator (skipped)"

      if errors.any?
        puts ""
        puts "🚨 #{errors.count} error(s) occurred:"
        errors.first(10).each { |e| puts "  - #{e}" }
        puts "  ... and #{errors.count - 10} more" if errors.count > 10
        puts ""
        puts "⚠️  Run: cat log/migration_errors.json for full details"

        # Log full errors to file
        File.open("log/migration_errors.json", "w") do |f|
          f.write(errors.to_json)
        end

        # Non-blocking in backfill (might be transient)
        puts ""
        puts "⚠️  Backfill completed with errors (non-blocking)"
      else
        puts ""
        puts "✅ Backfill completed successfully - no errors"
      end

      puts ""
      puts "📊 Statistics:"
      puts "  - Total missions: #{Mission.count}"
      puts "  - Total user_missions: #{UserMission.count}"
      puts "  - Missions without creator: #{Mission.where(created_by_user_id: nil).count}"
    end

    desc "PHASE 2: Backfill user_cras from historical cras (IDEMPOTENT)"
    task backfill_cras: :environment do
      puts "=" * 60
      puts "🔄 PHASE 2: Backfilling user_cras from historical data"
      puts "=" * 60

      migrated = 0
      skipped = 0
      errors = []

      Cra.find_each do |cra|
        # Skip cras without creator
        if cra.created_by_user_id.nil?
          skipped += 1
          next
        end

        # IDEMPOTENT: Use find_or_create_by! to allow re-running
        user_cra = UserCra.find_or_create_by!(
          cra_id: cra.id,
          role: "creator"
        ) do |uc|
          uc.user_id = cra.created_by_user_id
          uc.created_at = cra.created_at || Time.current
        end

        migrated += 1 if user_cra.persisted?
      rescue ActiveRecord::RecordNotUnique => e
        errors << "RecordNotUnique for cra #{cra.id}: #{e.message}"
      rescue StandardError => e
        errors << "Error for cra #{cra.id}: #{e.message}"
      end

      puts ""
      puts "✅ #{migrated} user_cras created or verified"
      puts "⚠️  #{skipped} cras without creator (skipped)"

      if errors.any?
        puts ""
        puts "🚨 #{errors.count} error(s) occurred:"
        errors.first(10).each { |e| puts "  - #{e}" }
        puts "  ... and #{errors.count - 10} more" if errors.count > 10
        puts ""
        puts "⚠️  Run: cat log/migration_errors.json for full details"

        # Log full errors to file
        File.open("log/migration_errors.json", "a") do |f|
          f.write(errors.to_json)
        end

        puts ""
        puts "⚠️  Backfill completed with errors (non-blocking)"
      else
        puts ""
        puts "✅ Backfill completed successfully - no errors"
      end

      puts ""
      puts "📊 Statistics:"
      puts "  - Total cras: #{Cra.count}"
      puts "  - Total user_cras: #{UserCra.count}"
      puts "  - Cras without creator: #{Cra.where(created_by_user_id: nil).count}"
    end

    desc "PHASE 3: Verify migration integrity (BLOCKING - will exit 1 on failure)"
    task verify_integrity: :environment do
      puts "=" * 60
      puts "🔍 PHASE 3: Verifying migration integrity"
      puts "=" * 60

      errors = []

      # 1. Check missions have exactly 1 creator
      puts ""
      puts "📋 Check 1: All missions have exactly 1 creator"

      orphan_missions = Mission.left_joins(:user_missions)
                               .where(user_missions: { id: nil })

      if orphan_missions.exists?
        error_msg = "#{orphan_missions.count} missions without creator (BLOCKING)"
        errors << error_msg
        puts "  🚨 #{error_msg}"
        puts "     Run: Mission.where.not(id: UserMission.select(:mission_id)).ids"
      else
        puts "  ✅ All #{Mission.count} missions have at least one creator"
      end

      # 2. Check cras have exactly 1 creator
      puts ""
      puts "📋 Check 2: All cras have exactly 1 creator"

      orphan_cras = Cra.left_joins(:user_cras)
                       .where(user_cras: { id: nil })

      if orphan_cras.exists?
        error_msg = "#{orphan_cras.count} cras without creator (BLOCKING)"
        errors << error_msg
        puts "  🚨 #{error_msg}"
      else
        puts "  ✅ All #{Cra.count} cras have at least one creator"
      end

      # 3. Check no duplicate creators per mission
      puts ""
      puts "📋 Check 3: No mission has multiple creators"

      mission_creator_counts = UserMission
                               .creators
                               .group(:mission_id)
                               .count
                               .select { |_, count| count > 1 }

      if mission_creator_counts.any?
        error_msg = "#{mission_creator_counts.count} missions with multiple creators (BLOCKING)"
        errors << error_msg
        puts "  🚨 #{error_msg}"
        mission_creator_counts.each do |mission_id, count|
          puts "     Mission #{mission_id}: #{count} creators"
        end
      else
        puts "  ✅ All missions have exactly 1 creator"
      end

      # 4. Check no duplicate creators per cra
      puts ""
      puts "📋 Check 4: No cra has multiple creators"

      cra_creator_counts = UserCra
                           .creators
                           .group(:cra_id)
                           .count
                           .select { |_, count| count > 1 }

      if cra_creator_counts.any?
        error_msg = "#{cra_creator_counts.count} cras with multiple creators (BLOCKING)"
        errors << error_msg
        puts "  🚨 #{error_msg}"
      else
        puts "  ✅ All cras have exactly 1 creator"
      end

      # 5. Check all user_missions have valid user_id
      puts ""
      puts "📋 Check 5: All user_missions have valid user_id"

      invalid_user_missions = UserMission.where.not(user_id: User.select(:id))

      if invalid_user_missions.exists?
        error_msg = "#{invalid_user_missions.count} user_missions with invalid user_id (BLOCKING)"
        errors << error_msg
        puts "  🚨 #{error_msg}"
      else
        puts "  ✅ All user_missions have valid user_id"
      end

      # 6. Check all user_cras have valid user_id
      puts ""
      puts "📋 Check 6: All user_cras have valid user_id"

      invalid_user_cras = UserCra.where.not(user_id: User.select(:id))

      if invalid_user_cras.exists?
        error_msg = "#{invalid_user_cras.count} user_cras with invalid user_id (BLOCKING)"
        errors << error_msg
        puts "  🚨 #{error_msg}"
      else
        puts "  ✅ All user_cras have valid user_id"
      end

      # Final result
      puts ""
      puts "=" * 60

      if errors.any?
        puts "🚨 VERIFICATION FAILED: #{errors.count} error(s) found"
        puts ""
        puts "❌ DO NOT proceed to Phase C (constraints) until errors are fixed."
        puts ""
        puts "To retry after fixing:"
        puts "  1. Fix the root cause in the database"
        puts "  2. Re-run: rake foresy:migrate:backfill_missions"
        puts "  3. Re-run: rake foresy:migrate:backfill_cras"
        puts "  4. Re-run: rake foresy:migrate:verify_integrity"
        puts ""
        puts "Migration is BLOCKED until all checks pass."

        # Exit with error code
        exit(1)
      else
        puts "✅ VERIFICATION PASSED: All integrity checks successful"
        puts ""
        puts "🎉 Ready to proceed to Phase C (constraints + triggers)"
        puts ""
        puts "Next steps:"
        puts "  1. Run: rails db:migrate (Phase C - constraints)"
        puts "  2. Run: rails db:migrate (Phase D - triggers)"
        puts "  3. Deploy to staging and test"
      end

      puts "=" * 60
    end

    desc "PHASE 4: Pre-release health check (optional quick validation)"
    task health_check: :environment do
      puts "=" * 60
      puts "🏥 Pre-release Health Check"
      puts "=" * 60

      checks = {
        "Missions with creator" => [
          Mission.joins(:user_missions).count,
          Mission.count
        ],
        "Cras with creator" => [
          Cra.joins(:user_cras).count,
          Cra.count
        ],
        "UserMission records" => [UserMission.count],
        "UserCra records" => [UserCra.count],
        "Users with missions" => [
          User.joins(:user_missions).distinct.count,
          User.count
        ]
      }

      checks.each do |name, values|
        case values.size
        when 2
          status = values[0] == values[1] ? "✅" : "⚠️"
          puts "#{status} #{name}: #{values[0]}/#{values[1]}"
        else
          puts "✅ #{name}: #{values[0]}"
        end
      end

      puts "=" * 60
    end
  end
end
