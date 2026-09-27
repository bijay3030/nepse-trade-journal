class AddDataManagementAndIntegrityFeatures < ActiveRecord::Migration[8.0]
  def change
    change_table :trade_plans, bulk: true do |t|
      t.datetime :deleted_at
    end
    add_index :trade_plans, :deleted_at

    change_table :trade_executions, bulk: true do |t|
      t.datetime :deleted_at
    end
    add_index :trade_executions, :deleted_at

    change_table :trade_results, bulk: true do |t|
      t.datetime :deleted_at
    end
    add_index :trade_results, :deleted_at

    change_table :daily_journals, bulk: true do |t|
      t.references :user, foreign_key: true
      t.date :trade_date
      t.string :mood
      t.integer :discipline_score
      t.text :content
      t.datetime :deleted_at
    end
    add_index :daily_journals, :deleted_at
    add_index :daily_journals, [:user_id, :trade_date], unique: true

    create_table :audit_logs do |t|
      t.references :user, foreign_key: true
      t.string :auditable_type, null: false
      t.bigint :auditable_id, null: false
      t.string :action, null: false
      t.jsonb :changes_snapshot, default: {}, null: false
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end
    add_index :audit_logs, [:auditable_type, :auditable_id]
    add_index :audit_logs, :action

    create_table :daily_journal_versions do |t|
      t.references :daily_journal, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.integer :version_number, null: false
      t.string :mood
      t.integer :discipline_score
      t.text :content
      t.timestamps
    end
    add_index :daily_journal_versions, [:daily_journal_id, :version_number], unique: true, name: "index_journal_versions_on_journal_and_version"
  end
end
