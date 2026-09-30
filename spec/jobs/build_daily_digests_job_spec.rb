require "rails_helper"

RSpec.describe BuildDailyDigestsJob do
  it "builds a digest for each user who has it on" do
    on = create(:user)
    create(:user, digest_enabled: false)
    allow(Digests::Builder).to receive(:call).and_return(instance_double(DailyDigest))

    expect(described_class.perform_now).to eq(1)
    expect(Digests::Builder).to have_received(:call).with(on).once
  end
end
