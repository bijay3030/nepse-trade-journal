class StockDailyPriceSerializer < ActiveModel::Serializer
  attributes :id, :traded_on, :open_price, :high_price, :low_price, :close_price,
             :previous_close, :change_amount, :change_percent, :volume, :turnover, :total_trades

  def open_price
    object.open_price.to_f
  end

  def high_price
    object.high_price.to_f
  end

  def low_price
    object.low_price.to_f
  end

  def close_price
    object.close_price.to_f
  end

  def previous_close
    object.previous_close.to_f
  end

  def change_amount
    object.change_amount.to_f
  end

  def change_percent
    object.change_percent.to_f
  end

  def turnover
    object.turnover.to_f
  end
end
