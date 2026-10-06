require "rails_helper"

RSpec.describe Fundamentals::EpsGrowth do
  let(:stock) { create(:stock) }

  def report(fiscal_year, quarter, eps:, growth_rate: nil)
    stock.company_financials.create!(fiscal_year: fiscal_year, quarter: quarter, eps: eps, growth_rate: growth_rate, reported_on: Date.new(2026, 9, 30))
  end

  it "compares the latest quarter with the same quarter a year earlier" do
    report("081/082", "Q4", eps: 20.0)
    report("082/083", "Q3", eps: 24.0)
    report("082/083", "Q4", eps: 27.0, growth_rate: 33.5)

    expect(described_class.call(stock.reload)).to include(growth_pct: 35.0, source: "reported", fiscal_year: "082/083", quarter: "Q4", prior_eps: 20.0, strong: true)
  end

  it "falls back to Chukul's growth rate, reading either fiscal-year format" do
    report("2081/082", "Q3", eps: 10.0)
    report("082/083", "Q4", eps: 12.0, growth_rate: 12.4)

    expect(described_class.call(stock.reload)).to include(growth_pct: 12.4, source: "chukul", strong: false)
    expect(described_class.fiscal_start("2081/082")).to eq(81)
  end

  it "returns nil without a quarterly report or a growth figure" do
    report("latest", "Annual", eps: 5.0)
    expect(described_class.call(stock.reload)).to be_nil

    report("082/083", "Q1", eps: 3.0)
    expect(described_class.call(stock.reload)).to be_nil
  end
end
