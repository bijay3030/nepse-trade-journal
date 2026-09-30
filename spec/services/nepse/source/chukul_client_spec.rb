require "rails_helper"

RSpec.describe Nepse::Source::ChukulClient do
  def stub_json(body, code: 200)
    response = instance_double(HTTParty::Response, success?: code == 200, code: code, body: body.to_json)
    allow(HTTParty).to receive(:get).and_return(response)
  end

  describe "#history" do
    it "dates each bar by its Nepal-time session date" do
      # 2026-09-27T18:15Z is midnight on 2026-09-28 in Nepal.
      stub_json({ t: [ 1790532900.0, 1790187300.0 ], o: [ 2600, 2590 ], h: [ 2610, 2601 ], l: [ 2595, 2580 ],
                  c: [ 2607.92, 2598.1 ], vol: [ 0, 0 ], amt: [ 5.1e9, 4.2e9 ] })

      result = described_class.new.history("NEPSE", from: Date.new(2026, 9, 1), to: Date.new(2026, 9, 28))

      expect(result[:bars].map { _1[:traded_on] }).to eq([ Date.new(2026, 9, 24), Date.new(2026, 9, 28) ])
      expect(result[:bars].last).to include(close: 2607.92, turnover: 5.1e9)
    end

    it "reports an empty history" do
      stub_json({ t: [] })
      expect(described_class.new.history("NOPE", from: Date.current, to: Date.current)).to include(success: false)
    end
  end

  it "wraps HTTP errors and non-JSON bodies" do
    stub_json({}, code: 500)
    expect(described_class.new.companies).to eq(success: false, error: "HTTP 500")

    allow(HTTParty).to receive(:get).and_return(instance_double(HTTParty::Response, success?: true, body: "<html>"))
    expect(described_class.new.sectors).to eq(success: false, error: "Response was not JSON")
  end
end
