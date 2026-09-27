require "rails_helper"

RSpec.describe Nepse::DataProviders::HistoricalDataProvider do
  subject(:provider) { described_class.new(base_url: "https://test.yonepse.io") }

  describe "#fetch_historical_prices" do
    let(:symbol) { "NABIL" }
    let(:start_date) { Date.parse("2026-01-01") }
    let(:end_date) { Date.parse("2026-01-10") }

    context "when API returns historical array" do
      let(:sample_json) do
        [
          {
            "symbol" => "NABIL",
            "date" => "2026-01-02",
            "open" => 500,
            "high" => 520,
            "low" => 495,
            "close" => 515,
            "volume" => 10000
          },
          {
            "symbol" => "NABIL",
            "date" => "2026-01-05",
            "open" => 515,
            "high" => 530,
            "low" => 510,
            "close" => 525,
            "volume" => 12000
          }
        ]
      end

      let(:response_double) { instance_double(HTTParty::Response, success?: true, parsed_response: sample_json) }

      before do
        allow(HTTParty).to receive(:get).and_return(response_double)
      end

      it "parses and filters historical records within date range" do
        result = provider.fetch_historical_prices(symbol, start_date: start_date, end_date: end_date)

        expect(result[:success]).to be true
        expect(result[:valid_count]).to eq(2)
        expect(result[:records].first.close_price).to eq(515.0)
        expect(result[:records].second.close_price).to eq(525.0)
      end
    end

    context "when network error occurs" do
      before do
        allow(HTTParty).to receive(:get).and_raise(Net::OpenTimeout.new("historical timeout"))
      end

      it "handles timeout error safely and returns failure result" do
        result = provider.fetch_historical_prices(symbol)

        expect(result[:success]).to be false
        expect(result[:error]).to include("Network error")
        expect(result[:records]).to be_empty
      end
    end
  end
end
