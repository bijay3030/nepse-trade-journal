require "rails_helper"

RSpec.describe Nepse::Sectors do
  it "maps each source's naming to one canonical sector" do
    expect(described_class.canonical("Banking")).to eq("Commercial Banks")
    expect(described_class.canonical("Development Bank Limited")).to eq("Development Banks")
    expect(described_class.canonical("Hydro Power")).to eq("Hydropower")
    expect(described_class.canonical("NonLife")).to eq("Non-Life Insurance")
    expect(described_class.canonical("Promotor Share")).to eq("Promoter Share")
    expect(described_class.canonical("Corporate Debenture")).to eq("Corporate Debentures")
  end

  it "rejects junk values" do
    expect(described_class.canonical("s")).to be_nil
    expect(described_class.canonical(nil)).to be_nil
  end

  it "derives the security type from the sector" do
    expect(described_class.security_type_for("Mutual Fund")).to eq("Mutual Fund")
    expect(described_class.security_type_for("Corporate Debentures")).to eq("Debenture")
    expect(described_class.security_type_for("Hydropower")).to eq("Equity")
  end
end
