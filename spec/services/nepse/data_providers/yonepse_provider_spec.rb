require "rails_helper"

RSpec.describe Nepse::DataProviders::YonepseProvider do
  subject(:provider) { described_class.new(base_url: "https://test.yonepse.io") }

  let(:date) { Date.parse("2026-09-20") }

  describe "#fetch_daily_prices" do
    context "when API returns a successful response" do
      let(:sample_json) do
        [
          {
            "symbol" => "NABIL",
            "companyName" => "Nabil Bank Limited",
            "sector" => "Commercial Banks",
            "openPrice" => 500.0,
            "highPrice" => 525.0,
            "lowPrice" => 495.0,
            "closePrice" => 520.0,
            "previousClose" => 500.0,
            "change" => 20.0,
            "percentChange" => 4.0,
            "volume" => 15000,
            "turnover" => 7800000.0,
            "totalTrades" => 450
          },
          {
            "symbol" => "NTC",
            "companyName" => "Nepal Telecom",
            "sector" => "Others",
            "close" => 900.0,
            "volume" => 5000
          }
        ]
      end
      let(:response_double) { instance_double(HTTParty::Response, success?: true, parsed_response: sample_json) }

      before do
        allow(HTTParty).to receive(:get).and_return(response_double)
      end

      it "parses and normalizes daily price records successfully" do
        result = provider.fetch_daily_prices(date)

        expect(result[:success]).to be true
        expect(result[:valid_count]).to eq(2)

        record1 = result[:records].first
        expect(record1.symbol).to eq("NABIL")
        expect(record1.company_name).to eq("Nabil Bank Limited")
        expect(record1.sector).to eq("Commercial Banks")
        expect(record1.open_price).to eq(500.0)
        expect(record1.high_price).to eq(525.0)
        expect(record1.low_price).to eq(495.0)
        expect(record1.close_price).to eq(520.0)
        expect(record1.previous_close).to eq(500.0)
        expect(record1.change_amount).to eq(20.0)
        expect(record1.change_percent).to eq(4.0)
        expect(record1.volume).to eq(15000)
        expect(record1.turnover).to eq(7800000.0)
        expect(record1.total_trades).to eq(450)

        record2 = result[:records].second
        expect(record2.symbol).to eq("NTC")
        expect(record2.close_price).to eq(900.0)
        expect(record2.open_price).to eq(900.0) # safely defaulted to close_price
      end
    end

    context "when API response is malformed JSON" do
      let(:response_double) { instance_double(HTTParty::Response, success?: true, parsed_response: nil) }

      before do
        allow(HTTParty).to receive(:get).and_return(response_double)
      end

      it "handles JSON parse failure safely and returns failure result" do
        result = provider.fetch_daily_prices(date)

        expect(result[:success]).to be false
        expect(result[:error]).to include("Empty or invalid market data payload")
        expect(result[:records]).to be_empty
      end
    end

    context "when HTTP request fails or times out" do
      before do
        allow(HTTParty).to receive(:get).and_raise(Net::OpenTimeout.new("execution expired"))
      end

      it "handles timeout error safely and returns failure result" do
        result = provider.fetch_daily_prices(date)

        expect(result[:success]).to be false
        expect(result[:error]).to include("Network error")
        expect(result[:records]).to be_empty
      end
    end
  end
end
