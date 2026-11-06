module Api
  module V1
    # Indicator scans (Scans::Crossovers) with how each signal played out historically
    # (Scans::CrossoverBacktest), cached until the next completed session.
    class ScansController < BaseController
      def crossovers
        render json: Scans::Cache.crossovers
      end
    end
  end
end
