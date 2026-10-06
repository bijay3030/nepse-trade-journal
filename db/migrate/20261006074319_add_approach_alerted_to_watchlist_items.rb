class AddApproachAlertedToWatchlistItems < ActiveRecord::Migration[8.0]
  def change
    # Set when the "approaching the zone" alert fires; cleared once the price moves
    # well away again, so each approach alerts once.
    add_column :watchlist_items, :approach_alerted, :boolean, null: false, default: false
  end
end
