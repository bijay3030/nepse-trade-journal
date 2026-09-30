module Flows
  # Broker numbers to names, from Chukul.
  module BrokerSync
    module_function

    def call(client: Nepse::Source::ChukulClient.new)
      response = client.brokers
      return { success: false, error: response[:error] } unless response[:success]

      now = Time.current
      rows = Array(response[:data]).filter_map do |broker|
        number = broker["broker_no"].to_s.strip
        name = broker["broker_name"].to_s.strip
        { broker_no: number, name: name, created_at: now, updated_at: now } if number.present? && name.present?
      end
      Broker.upsert_all(rows, unique_by: :broker_no, update_only: %i[name]) if rows.any?
      { success: true, brokers: rows.size }
    end
  end
end
