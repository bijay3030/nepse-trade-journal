module Nepse
  class StockMasterSeeder
    def self.seed!
      Nepse::MasterImporterService.call
    end
  end
end
