class CreateDailyJournals < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_journals do |t|
      t.timestamps
    end
  end
end
