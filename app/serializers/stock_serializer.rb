class StockSerializer < ActiveModel::Serializer
  attributes :id, :symbol, :name, :sector, :security_type, :last_price, :change_percent,
             :volume, :listed_shares, :market_cap, :high_52w, :low_52w,
             :eps, :pe_ratio, :book_value, :pb_ratio, :last_updated

  def eps
    object.current_eps
  end

  def pe_ratio
    object.current_pe_ratio
  end

  def book_value
    object.current_book_value
  end

  def pb_ratio
    object.current_pb_ratio
  end
end
