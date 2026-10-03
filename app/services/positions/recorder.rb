module Positions
  # Records buys: the first one opens a position (stop and target from the watchlist
  # setup, stop capped at Position::MAX_STOP_PCT below entry) and marks the watchlist
  # item "holding"; later ones add to the same open position. Removing the last fill
  # removes the position and puts the watchlist item back to tracking.
  module Recorder
    module_function

    def buy(user:, stock:, price:, quantity:, traded_on:, watchlist_item: nil)
      watchlist_item ||= user.watchlist_items.find_by(stock: stock)
      Position.transaction do
        position = user.positions.open.find_by(stock: stock) || open_position(user, stock, watchlist_item, price)
        position.fills.create!(side: "buy", price: price, quantity: quantity, traded_on: traded_on)
        watchlist_item&.update!(status: "holding")
        position.reload
      end
    end

    def remove_fill(fill)
      position = fill.position
      Position.transaction do
        fill.destroy!
        if position.fills.reload.empty?
          item = position.watchlist_item
          position.destroy!
          resume_tracking(item) if item
          nil
        else
          position.reload
        end
      end
    end

    def open_position(user, stock, item, entry)
      stop = Position.default_stop(entry, item && (item.stop_loss_price.presence || item.invalidation_price))
      user.positions.create!(stock: stock, watchlist_item: item, setup_type: item&.setup_type,
                             stop_price: stop, initial_stop_price: stop, target_price: item&.target_price)
    end

    def resume_tracking(item)
      return unless item.status == "holding"

      item.update!(status: "watching")
      Watchlist::AlertEvaluator.initial_state!(item)
    end
  end
end
