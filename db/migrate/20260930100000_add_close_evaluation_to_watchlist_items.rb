class AddCloseEvaluationToWatchlistItems < ActiveRecord::Migration[8.0]
  def change
    # End-of-day verdict for the latest session, from the close and full-day volume.
    add_column :watchlist_items, :last_close_on, :date
    add_column :watchlist_items, :last_close_state, :string
    add_column :watchlist_items, :last_close_price, :decimal, precision: 12, scale: 2
    add_column :watchlist_items, :last_close_relative_volume, :decimal, precision: 8, scale: 2
    # Whether the price reached the zone during the day, for spotting failed breakouts.
    add_column :watchlist_items, :touched_zone_on, :date
  end
end
