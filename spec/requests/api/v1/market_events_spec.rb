require "rails_helper"

RSpec.describe "Market events", type: :request do
  let(:user) { create(:user) }
  let(:headers) { { "Authorization" => "Bearer #{JWT.encode({ jti: user.jti, sub: user.id }, 'secret', 'HS256')}" } }
  let(:today) { Nepse::MarketHours.today }
  let(:mine) { create(:stock, symbol: "MINE", name: "Mine Limited") }
  let(:other) { create(:stock, symbol: "OTHR", name: "Other Limited") }

  before do
    create(:watchlist_item, user: user, stock: mine)
    allow(Events::Alerts).to receive(:lab_stock_ids).and_return(Set.new)
    allow(Events::BookCloseStudy).to receive(:cached).and_return({ window: 20, events: 0, groups: [], all: { count: 0 } })
    MarketEvent.create!(stock: mine, source: "sharesansar", external_id: "a", kind: "results", impact: "negative", title: "Mine loss", reason: "Net loss", published_on: today)
    MarketEvent.create!(stock: other, source: "chukul_bonus", external_id: "b", kind: "bonus", impact: "positive", title: "OTHR bonus", reason: "Bonus", published_on: today - 1, event_on: today + 3)
  end

  it "lists events, marks the user's stocks, filters, and shows book closes ahead" do
    get "/api/v1/market_events", headers: headers
    body = response.parsed_body
    expect(body["events"].map { _1["symbol"] }).to eq(%w[MINE OTHR])
    expect(body["events"].first).to include("mine" => true, "impact" => "negative", "kind" => "results")
    expect(body["upcoming"].sole).to include("symbol" => "OTHR", "event_on" => (today + 3).iso8601)
    expect(body["study"]).to include("window" => 20)

    get "/api/v1/market_events", params: { scope: "mine" }, headers: headers
    expect(response.parsed_body["events"].map { _1["symbol"] }).to eq(%w[MINE])
    get "/api/v1/market_events", params: { impact: "positive" }, headers: headers
    expect(response.parsed_body["events"].map { _1["symbol"] }).to eq(%w[OTHR])
  end

  it "filters by announcement date and stock, and pages the results" do
    30.times do |i|
      MarketEvent.create!(stock: other, source: "sharesansar", external_id: "p#{i}", kind: "other", impact: "neutral", title: "Other Limited notice #{i}",
                          reason: "Notice", published_on: today - 40 - (i % 3))
    end
    MarketEvent.create!(stock: nil, source: "sharesansar", external_id: "u", kind: "agm", impact: "neutral", title: "Orbit Energy Limited has announced its 3rd AGM",
                        reason: "AGM", published_on: today - 41)

    get "/api/v1/market_events", params: { from: (today - 45).iso8601, to: (today - 39).iso8601, per: 10, page: 2 }, headers: headers
    body = response.parsed_body
    expect(body["pagination"]).to eq("page" => 2, "per" => 10, "total" => 31, "pages" => 4)
    expect(body["events"].size).to eq(10)
    expect(body["from"]).to eq((today - 45).iso8601)

    get "/api/v1/market_events", params: { from: (today - 45).iso8601, to: (today - 39).iso8601, q: "orbit" }, headers: headers
    expect(response.parsed_body["events"].map { _1["title"] }).to eq([ "Orbit Energy Limited has announced its 3rd AGM" ]) # unlisted: found by its announcement
    get "/api/v1/market_events", params: { q: "MIN" }, headers: headers
    expect(response.parsed_body["events"].map { _1["symbol"] }).to eq(%w[MINE])

    get "/api/v1/market_events", params: { page: 99 }, headers: headers
    expect(response.parsed_body["pagination"]).to include("page" => 1, "pages" => 1) # clamped
  end
end
