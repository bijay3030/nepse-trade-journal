require "rails_helper"

RSpec.describe Flows::BrokerSync do
  it "stores broker names by number and updates renamed ones" do
    client = instance_double(Nepse::Source::ChukulClient)
    Broker.create!(broker_no: "1", name: "Old name")
    allow(client).to receive(:brokers).and_return({ success: true, data: [
      { "broker_no" => "1", "broker_name" => "Kumari Securities Pvt. Limited" }, { "broker_no" => "3", "broker_name" => "Arun Securities Pvt. Limited" }
    ] })

    expect(described_class.call(client: client)).to eq(success: true, brokers: 2)
    expect(Broker.order(:broker_no).pluck(:broker_no, :name)).to eq([ [ "1", "Kumari Securities Pvt. Limited" ], [ "3", "Arun Securities Pvt. Limited" ] ])
  end
end
