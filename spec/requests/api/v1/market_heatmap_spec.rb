require "rails_helper"

RSpec.describe "Market heatmap", type: :request do
  def stock(symbol, sector, change, cap, **attrs)
    create(:stock, symbol: symbol, sector: sector, last_price: 100, change_percent: change, market_cap: cap,
                   last_updated: Time.zone.parse("2026-09-30 09:30"), **attrs)
  end

  it "groups stocks by sector, largest first, with a market-cap weighted sector change" do
    stock("NABIL", "Commercial Banks", 2.0, 300)
    stock("KBL", "Commercial Banks", -1.0, 100)
    stock("UPPER", "Hydropower", 4.0, 50)

    get "/api/v1/market/heatmap"
    body = JSON.parse(response.body)

    expect(body).to include("stocks" => 3, "unsized" => 0, "as_of" => "2026-09-30T09:30:00Z")
    banks, hydro = body["sectors"]
    expect(banks).to include("sector" => "Commercial Banks", "market_cap" => 400.0, "change_percent" => 1.25, "advancing" => 1, "declining" => 1)
    expect(banks["stocks"].map { _1["symbol"] }).to eq(%w[NABIL KBL])
    expect(hydro["sector"]).to eq("Hydropower")
  end

  it "counts stocks it can't size and leaves out inactive stocks and debentures" do
    stock("NABIL", "Commercial Banks", 1.0, 300)
    stock("NOCAP", "Hydropower", 1.0, 0)
    stock("OLD", "Hydropower", 1.0, 100, is_active: false)
    stock("PBD84", "Corporate Debentures", 0.1, 5_000)

    get "/api/v1/market/heatmap"
    body = JSON.parse(response.body)

    expect(body).to include("stocks" => 1, "unsized" => 1)
    expect(body["sectors"].map { _1["sector"] }).to eq([ "Commercial Banks" ])
  end
end
