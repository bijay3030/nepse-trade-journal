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

    # Records a sell. Selling every share closes the position (and archives its watchlist
    # item). Selling shares that haven't settled (T+2) is recorded with a warning: the
    # record mirrors what was done on TMS.
    def sell(position:, price:, quantity:, traded_on:)
      quantity = quantity.to_i
      traded_on = Date.parse(traded_on.to_s) unless traded_on.is_a?(Date)
      raise ArgumentError, "You hold #{position.quantity} shares; can't sell #{quantity}" unless quantity.positive? && quantity <= position.quantity

      unsettled = [ quantity - position.settled_quantity(traded_on), 0 ].max
      Position.transaction do
        position.fills.create!(side: "sell", price: price, quantity: quantity, traded_on: traded_on)
        position.reload
        if position.quantity.zero?
          position.update!(status: "closed", closed_on: traded_on)
          position.watchlist_item&.update!(status: "archived")
        end
      end
      warning = "#{unsettled} of these shares hadn't settled (T+2) on #{traded_on.strftime('%-d %b')}" if unsettled.positive?
      [ position.reload, warning ]
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
          # Removing a sell can reopen a closed position.
          position.update!(status: "open", closed_on: nil) if position.status == "closed" && position.quantity.positive?
          position
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
