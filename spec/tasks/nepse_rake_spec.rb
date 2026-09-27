require "rails_helper"
require "rake"

RSpec.describe "nepse rake tasks" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("nepse:seed_stocks")
  end

  before do
    %w[
      nepse:seed_stocks
      nepse:sync_market
      nepse:sync_fundamentals
      nepse:sync_stock_basics
      nepse:scrape_market
      nepse:scrape_fundamentals
      nepse:scrape_all
    ].each do |task_name|
      Rake::Task[task_name].reenable if Rake::Task.task_defined?(task_name)
    end
  end

  it "uses the canonical master importer for nepse:seed_stocks" do
    allow(Nepse::MasterImporterService).to receive(:call).and_return(success: true, created: 2, updated: 1, total: 3)

    Rake::Task["nepse:seed_stocks"].invoke

    expect(Nepse::MasterImporterService).to have_received(:call)
  end

  it "defines the explicit stock basics sync tasks" do
    expect(Rake::Task.task_defined?("nepse:sync_market")).to be(true)
    expect(Rake::Task.task_defined?("nepse:sync_fundamentals")).to be(true)
    expect(Rake::Task.task_defined?("nepse:sync_stock_basics")).to be(true)
  end

  it "routes nepse:sync_market through nepse:seed_stocks" do
    allow(Nepse::MasterImporterService).to receive(:call).and_return(success: true, created: 1, updated: 0, total: 1)
    allow(Nepse::StockBasicsSyncService).to receive(:sync_market).and_return(success: true, processed: 1, rejected_symbols: [], total_rows: 1)

    Rake::Task["nepse:sync_market"].invoke

    expect(Nepse::MasterImporterService).to have_received(:call).once
    expect(Nepse::StockBasicsSyncService).to have_received(:sync_market)
  end

  it "stops nepse:sync_market when nepse:seed_stocks fails" do
    allow(Nepse::MasterImporterService).to receive(:call).and_return(success: false, error: "seed failed")
    allow(Nepse::StockBasicsSyncService).to receive(:sync_market)

    expect { Rake::Task["nepse:sync_market"].invoke }.to raise_error(RuntimeError, "seed failed")

    expect(Nepse::StockBasicsSyncService).not_to have_received(:sync_market)
  end

  it "routes nepse:sync_fundamentals through nepse:seed_stocks" do
    allow(Nepse::MasterImporterService).to receive(:call).and_return(success: true, created: 1, updated: 0, total: 1)
    allow(Nepse::StockBasicsSyncService).to receive(:sync_fundamentals).and_return(
      success: true,
      total_symbols: 1,
      processed: 1,
      failed_symbols: [],
      aborted: false
    )

    Rake::Task["nepse:sync_fundamentals"].invoke

    expect(Nepse::MasterImporterService).to have_received(:call).once
    expect(Nepse::StockBasicsSyncService).to have_received(:sync_fundamentals)
  end

  it "routes nepse:sync_stock_basics through nepse:seed_stocks" do
    allow(Nepse::MasterImporterService).to receive(:call).and_return(success: true, created: 1, updated: 0, total: 1)
    allow(Nepse::StockBasicsSyncService).to receive(:call).and_return(
      success: true,
      seed: { success: true, created: 1, updated: 0, total: 1 },
      market: { success: true, processed: 1, rejected_symbols: [], total_rows: 1 },
      fundamentals: { success: true, total_symbols: 1, processed: 1, failed_symbols: [], aborted: false }
    )

    Rake::Task["nepse:sync_stock_basics"].invoke

    expect(Nepse::MasterImporterService).to have_received(:call).once
    expect(Nepse::StockBasicsSyncService).to have_received(:call)
  end

  it "stops nepse:sync_stock_basics after a market-sync failure" do
    allow(Nepse::MasterImporterService).to receive(:call).and_return(success: true, created: 1, updated: 0, total: 1)
    allow(Nepse::StockBasicsSyncService).to receive(:call).and_return(
      success: false,
      seed: { success: true, created: 1, updated: 0, total: 1 },
      market: { success: false, error: "market failed", processed: 0, rejected_symbols: [] }
    )

    Rake::Task["nepse:sync_stock_basics"].invoke

    expect(Nepse::MasterImporterService).to have_received(:call).once
    expect(Nepse::StockBasicsSyncService).to have_received(:call)
  end

  it "keeps nepse:scrape_market as a compatibility alias for nepse:sync_market" do
    allow(Nepse::MasterImporterService).to receive(:call).and_return(success: true, created: 1, updated: 0, total: 1)
    allow(Nepse::StockBasicsSyncService).to receive(:sync_market).and_return(success: true, processed: 1, rejected_symbols: [], total_rows: 1)

    Rake::Task["nepse:scrape_market"].invoke

    expect(Nepse::MasterImporterService).to have_received(:call).once
    expect(Nepse::StockBasicsSyncService).to have_received(:sync_market)
  end

  it "keeps nepse:scrape_fundamentals as a compatibility alias for nepse:sync_fundamentals" do
    allow(Nepse::MasterImporterService).to receive(:call).and_return(success: true, created: 1, updated: 0, total: 1)
    allow(Nepse::StockBasicsSyncService).to receive(:sync_fundamentals).and_return(
      success: true,
      total_symbols: 1,
      processed: 1,
      failed_symbols: [],
      aborted: false
    )

    Rake::Task["nepse:scrape_fundamentals"].invoke

    expect(Nepse::MasterImporterService).to have_received(:call).once
    expect(Nepse::StockBasicsSyncService).to have_received(:sync_fundamentals)
  end

  it "formats nepse:import_csv failures when only result[:error] is present" do
    allow(Nepse::CsvImporterService).to receive(:call).and_return(success: false, imported: 0, error: "bad csv")

    expect do
      Rake::Task["nepse:import_csv"].invoke("tmp/sample.csv", "prices")
    end.to output(/Import completed with errors\. Imported: 0\. Errors: bad csv/).to_stdout
  end

  it "routes nepse:scrape_all through the canonical stock basics sync" do
    allow(Nepse::MasterImporterService).to receive(:call).and_return(success: true, created: 1, updated: 0, total: 1)
    allow(Nepse::StockBasicsSyncService).to receive(:call).and_return(
      success: true,
      seed: { success: true, created: 1, updated: 0, total: 1 },
      market: { success: true, processed: 1, rejected_symbols: [], total_rows: 1 },
      fundamentals: { success: true, total_symbols: 1, processed: 1, failed_symbols: [], aborted: false }
    )

    Rake::Task["nepse:scrape_all"].invoke

    expect(Nepse::MasterImporterService).to have_received(:call).once
    expect(Nepse::StockBasicsSyncService).to have_received(:call)
  end
end
