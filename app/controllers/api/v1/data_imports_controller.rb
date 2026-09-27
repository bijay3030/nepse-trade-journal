module Api
  module V1
    class DataImportsController < BaseController
      def seed_master
        result = Nepse::MasterImporterService.call
        if result[:success]
          render json: { message: "Master stocks seeded successfully", details: result }
        else
          render json: { error: result[:error] || result[:message] }, status: :unprocessable_entity
        end
      end

      def sync_daily_prices
        date = params[:date].present? ? Date.parse(params[:date]) : Date.current
        result = Nepse::DailyPriceImporterService.call(date)

        if result[:success]
          render json: { message: "Daily prices sync initiated/completed", details: result }
        else
          render json: { error: result[:error] }, status: :unprocessable_entity
        end
      end

      def import_csv
        file = params[:file]
        type = params[:type] || "prices"

        if file.blank?
          render json: { error: "CSV file is required" }, status: :bad_request
          return
        end

        result = Nepse::CsvImporterService.call(file, type: type)

        if result[:success]
          render json: { message: "CSV imported successfully", imported_count: result[:imported] }
        else
          render json: { error: "CSV import completed with errors", imported_count: result[:imported], errors: result[:errors] }, status: :unprocessable_entity
        end
      end
    end
  end
end
