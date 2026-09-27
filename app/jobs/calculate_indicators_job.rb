class CalculateIndicatorsJob < ApplicationJob
  queue_as :default

  def perform(symbols = nil, batch_size = 20, recalculate_all = false)
    Rails.logger.info("Executing CalculateIndicatorsJob for symbols: #{symbols.inspect}")

    result = Indicators::BatchCalculatorService.call(
      symbols: symbols,
      batch_size: batch_size,
      recalculate_all: recalculate_all
    )

    Rails.logger.info("CalculateIndicatorsJob completed: #{result.inspect}")
    result
  end
end
