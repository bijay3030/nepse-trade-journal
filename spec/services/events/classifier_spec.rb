require "rails_helper"

RSpec.describe Events::Classifier do
  it "rates bonus and dividend proposals, and no dividend" do
    big = described_class.dividend(bonus: 14, cash: 4.42, book_close_on: Date.new(2026, 12, 4), year: "082/083")
    expect(big).to include(kind: "bonus", impact: "positive", important: true)
    expect(big[:reason]).to include("14% bonus shares and 4.42% cash dividend proposed for 082/083", "Book close 4 Dec 2026")
    expect(described_class.dividend(bonus: 0, cash: 5.26)).to include(kind: "cash_dividend", impact: "positive", important: false)
    expect(described_class.dividend(bonus: 0, cash: 0)).to include(impact: "negative")
  end

  it "rates rights issues as mixed: dilution, though prices rose around past rights book closes" do
    rated = described_class.rights(right: 50, book_close_on: Date.new(2026, 11, 27))
    expect(rated).to include(kind: "rights", impact: "mixed", important: true)
    expect(rated[:reason]).to include("50% rights shares (1 for every 2 held)", "Book close 27 Nov 2026")
  end

  it "reads quarterly results, comparing with the same quarter of an earlier year" do
    loss = described_class.title("Palpa Cements Industries Limited has posted a net loss of Rs 137.64 million and published its 1st quarter company analysis of the fiscal year 2083/84.")
    expect(loss).to include(kind: "results", impact: "negative")
    expect(loss[:data]).to include(net_profit_m: -137.64, quarter: 1, fiscal_year: "2083/84")

    no_rs = described_class.title("Ankhukhola Jalvidhyut Company Limited has posted a net profit of 20.06 million and published its 1st quarter company analysis of the fiscal year 2083/84.")
    expect(no_rs).to include(kind: "results", impact: "neutral")

    previous = MarketEvent.new(data: { "net_profit_m" => 15.0 })
    up = described_class.title("X Limited has posted a net profit of Rs 20 million and published its 1st quarter company analysis of the fiscal year 2083/84.", previous_result: previous)
    expect(up).to include(impact: "positive")
    expect(up[:reason]).to include("up from Rs 15M (+33.3%)")
    down = described_class.title("X Limited has posted a net profit of Rs 10 million and published its 1st quarter company analysis.", previous_result: previous)
    expect(down).to include(impact: "negative")
  end

  it "reads promoter, merger, regulatory, AGM and other notices" do
    expect(described_class.title("The existing promoter of Nepal Finance Limited is selling 2,31,403 shares to the other person")).to include(kind: "promoter_sale", impact: "negative")
    expect(described_class.title("Nabil Investment Banking Limited has published a notice regarding the cancellation of the sale of promoter shares")).to include(impact: "positive")
    expect(described_class.title("Promoter shares of ABC Limited lock-in period ends")).to include(kind: "promoter_lockin", impact: "negative")
    expect(described_class.title("ABC Bank and XYZ Bank sign merger agreement")).to include(kind: "merger", impact: "mixed")
    expect(described_class.title("NEPSE halts trading of ABC Limited shares")).to include(kind: "regulatory", impact: "negative", important: true)
    expect(described_class.title("ABC Limited has announced its 6th AGM going to be held on 27th Mangsir")).to include(kind: "agm", impact: "neutral")
    expect(described_class.title("ABC Limited AGM approves 10% bonus and cash dividend")).to include(impact: "positive")
    expect(described_class.title("ABC Limited's credit rating upgraded to A")).to include(kind: "credit_rating", impact: "positive")
    expect(described_class.title("ABC Limited has published a notice regarding the new interest rate")).to include(kind: "other", impact: "neutral")
  end
end
