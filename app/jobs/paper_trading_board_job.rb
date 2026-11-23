# After the nightly analysis: paper buys (pending until the next session) for stocks new
# on Entry zone now (PaperTrading::Engine.on_board).
class PaperTradingBoardJob < ApplicationJob
  queue_as :default

  def perform
    session = StockSetupSnapshot.maximum(:traded_on) or return
    PaperTrading::Engine.on_board(session)
  end
end
