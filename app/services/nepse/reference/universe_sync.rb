module Nepse
  module Reference
    # Keeps the list of listed securities in step with Chukul's company list:
    # adds missing ones, corrects names, sectors and security types, and marks
    # merged or delisted companies inactive. Stocks Chukul does not know are left alone.
    class UniverseSync
      PLACEHOLDER_NAME = / Company\z/

      def self.call(client: Source::ChukulClient.new)
        new(client).call
      end

      def initialize(client)
        @client = client
      end

      def call
        response = @client.companies
        return { success: false, error: "Chukul company list: #{response[:error]}" } unless response[:success]

        summary = { success: true, created: [], updated: 0, deactivated: [], skipped: [] }
        stocks = Stock.all.index_by(&:symbol)

        Array(response[:data]).each do |company|
          symbol = company["symbol"].to_s.upcase.strip
          sector, security_type = Sectors::CHUKUL[company["sector"]]
          next summary[:skipped] << symbol if symbol.blank? || sector.nil?

          listed = !company["is_delisted"] && !company["is_merged"]
          stock = stocks[symbol]
          next if stock.nil? && !listed # never add companies that are already gone

          stock ||= Stock.new(symbol: symbol, last_updated: Time.current)
          was_new = stock.new_record?
          Provenance.assign(stock, { name: company["name"].to_s.strip, sector: sector, security_type: security_type }, "chukul")
          stock.chukul_id = company["id"]
          stock.chukul_sector_id = company["sector"]
          if stock.is_active != listed
            stock.is_active = listed
            summary[:deactivated] << symbol unless listed
          end
          next unless stock.changed?

          stock.save!
          was_new ? summary[:created] << symbol : summary[:updated] += 1
        end

        summary.merge(cleaned: clean_unknown_sectors)
      end

      private

      # Stocks outside Chukul's list keep their data, but junk or variant sector
      # names are normalised (the Stock model canonicalises on save).
      def clean_unknown_sectors
        Stock.where(chukul_id: nil).find_each.count do |stock|
          canonical = Sectors.canonical(stock.sector)
          next false if canonical.nil? || canonical == stock.sector

          stock.update!(sector: canonical)
        end
      end
    end
  end
end
