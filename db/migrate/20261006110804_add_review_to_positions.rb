class AddReviewToPositions < ActiveRecord::Migration[8.0]
  def change
    # Post-trade review: did the trader follow the plan, what went wrong, the lesson.
    add_column :positions, :review_plan_followed, :string
    add_column :positions, :review_tags, :jsonb, null: false, default: []
    add_column :positions, :review_lesson, :text
    add_column :positions, :reviewed_at, :datetime
  end
end
