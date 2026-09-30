module Nepse
  # One canonical sector name per NEPSE sector, whatever the source calls it.
  module Sectors
    # Chukul sector id => [canonical sector, security type]
    CHUKUL = {
      1 => [ "Commercial Banks", "Equity" ],
      2 => [ "Development Banks", "Equity" ],
      3 => [ "Finance", "Equity" ],
      4 => [ "Hotels And Tourism", "Equity" ],
      5 => [ "Hydropower", "Equity" ],
      6 => [ "Investment", "Equity" ],
      7 => [ "Life Insurance", "Equity" ],
      8 => [ "Manufacturing And Processing", "Equity" ],
      9 => [ "Microfinance", "Equity" ],
      10 => [ "Non-Life Insurance", "Equity" ],
      11 => [ "Others", "Equity" ],
      12 => [ "Tradings", "Equity" ],
      13 => [ "Mutual Fund", "Mutual Fund" ],
      14 => [ "Promoter Share", "Promoter Share" ],
      15 => [ "Corporate Debentures", "Debenture" ]
    }.freeze

    # Sector index symbol (Chukul) => [canonical sector, Merolagani chart symbol, checked 2026-09-28]
    INDICES = {
      "BANKINGIND" => [ "Commercial Banks", "BANKING" ],
      "DEVBANKIND" => [ "Development Banks", "DEVELOPMENT BANK" ],
      "FINANCEIND" => [ "Finance", "FINANCE" ],
      "HOTELIND" => [ "Hotels And Tourism", "HOTELS AND TOURISM" ],
      "HYDROPOWIND" => [ "Hydropower", "HYDROPOWER" ],
      "INVIDX" => [ "Investment", "INVESTMENT" ],
      "LIFEINSUIND" => [ "Life Insurance", "LIFE INSURANCE" ],
      "MANUFACTUREIND" => [ "Manufacturing And Processing", nil ], # no Merolagani symbol found
      "MICROFININD" => [ "Microfinance", "MICROFINANCE" ],
      "NONLIFEIND" => [ "Non-Life Insurance", "NON-LIFE INSURANCE" ],
      "OTHERSIND" => [ "Others", "OTHERS" ],
      "TRADINGIND" => [ "Tradings", "TRADING" ]
    }.freeze

    ALIASES = {
      "banking" => "Commercial Banks", "commercialbank" => "Commercial Banks", "commercialbanks" => "Commercial Banks",
      "devbanks" => "Development Banks", "developmentbank" => "Development Banks", "developmentbanks" => "Development Banks",
      "developmentbanklimited" => "Development Banks",
      "finance" => "Finance",
      "hotels" => "Hotels And Tourism", "hotelandtourism" => "Hotels And Tourism", "hotelsandtourism" => "Hotels And Tourism",
      "hydropower" => "Hydropower",
      "investment" => "Investment",
      "lifeinsurance" => "Life Insurance",
      "manufacturing" => "Manufacturing And Processing", "manufacturingandprocessing" => "Manufacturing And Processing",
      "microfinance" => "Microfinance",
      "nonlife" => "Non-Life Insurance", "nonlifeinsurance" => "Non-Life Insurance", "insurance" => "Non-Life Insurance",
      "others" => "Others",
      "trading" => "Tradings", "tradings" => "Tradings",
      "mutualfund" => "Mutual Fund",
      "promoter" => "Promoter Share", "promotershare" => "Promoter Share", "promotorshare" => "Promoter Share",
      "debenture" => "Corporate Debentures", "corporatedebenture" => "Corporate Debentures", "corporatedebentures" => "Corporate Debentures"
    }.freeze

    module_function

    # Returns the canonical name, or nil for unknown or junk values (e.g. "s").
    def canonical(name)
      ALIASES[name.to_s.downcase.gsub(/[^a-z]/, "")]
    end

    def security_type_for(sector)
      case sector
      when "Mutual Fund" then "Mutual Fund"
      when "Promoter Share" then "Promoter Share"
      when "Corporate Debentures" then "Debenture"
      else "Equity"
      end
    end
  end
end
