# Market heatmap: active equities grouped by sector, each with its market cap and
# the day's change (live during market hours, the last close otherwise). Sector
# change is market-cap weighted, like an index. Stocks without a price or market
# cap can't be sized and are counted instead. Debentures are listed as equities
# by one source, so their sector is left out.
class MarketIndex::Heatmap
  EXCLUDED_SECTORS = [ "Corporate Debentures" ].freeze

  def call
    stocks = Stock.active.where(security_type: "Equity").where.not(sector: EXCLUDED_SECTORS)
    sized = stocks.where("market_cap > 0 AND last_price > 0")
    rows = sized.pluck(:symbol, :name, :sector, :last_price, :change_percent, :market_cap, :last_updated)

    sectors = rows.group_by { _1[2] }.map do |sector, members|
      tiles = members.map do |symbol, name, _, price, change, cap|
        { symbol: symbol, name: name, last_price: price.to_f, change_percent: change.to_f.round(2), market_cap: cap.to_f }
      end.sort_by { -_1[:market_cap] }
      cap = tiles.sum { _1[:market_cap] }
      {
        sector: sector,
        market_cap: cap,
        change_percent: (tiles.sum { _1[:change_percent] * _1[:market_cap] } / cap).round(2),
        advancing: tiles.count { _1[:change_percent].positive? },
        declining: tiles.count { _1[:change_percent].negative? },
        stocks: tiles
      }
    end.sort_by { -_1[:market_cap] }

    {
      as_of: rows.filter_map(&:last).max&.iso8601,
      stocks: rows.size,
      unsized: stocks.count - rows.size,
      sectors: sectors
    }
  end
end
