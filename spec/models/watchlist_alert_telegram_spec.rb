require "rails_helper"

RSpec.describe WatchlistAlert do
  let(:user) { create(:user, telegram_chat_id: "42") }
  let(:item) { create(:watchlist_item, user: user) }

  before { allow(Telegram::Client).to receive(:configured?).and_return(true) }

  it "queues a Telegram message for a zone entry of a linked user" do
    expect { user.watchlist_alerts.create!(watchlist_item: item, kind: "entered_zone", message: "x") }.to have_enqueued_job(TelegramAlertJob)
  end

  it "doesn't queue other kinds, unlinked users, or when Telegram isn't set up" do
    expect { user.watchlist_alerts.create!(watchlist_item: item, kind: "invalidated", message: "x") }.not_to have_enqueued_job(TelegramAlertJob)
    user.update!(telegram_chat_id: nil)
    expect { user.watchlist_alerts.create!(watchlist_item: item, kind: "entered_zone", message: "x") }.not_to have_enqueued_job(TelegramAlertJob)
    user.update!(telegram_chat_id: "42")
    allow(Telegram::Client).to receive(:configured?).and_return(false)
    expect { user.watchlist_alerts.create!(watchlist_item: item, kind: "breakout_confirmed", message: "x") }.not_to have_enqueued_job(TelegramAlertJob)
  end
end
