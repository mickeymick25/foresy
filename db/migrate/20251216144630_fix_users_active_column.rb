class FixUsersActiveColumn < ActiveRecord::Migration[7.1]
  def up
    # Étape 1: Backfill les utilisateurs existants
    # (Avant de changer les contraintes pour éviter les erreurs)
    User.where(active: nil).update_all(active: true)

    # Étape 2: Ajouter la contrainte NOT NULL
    change_column_null :users, :active, false

    # Étape 3: Ajouter la valeur par défaut
    change_column_default :users, :active, true
  end

  def down
    # Rollback: Supprimer la contrainte NOT NULL et la valeur par défaut
    change_column_default :users, :active, nil
    change_column_null :users, :active, true

    # Ne pas backfiller lors du rollback (on garde les données telles qu'elles étaient)
  end
end
