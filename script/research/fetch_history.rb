out = "#{ENV.fetch("STUDY_DIR", "tmp/research")}/history"
Dir.mkdir(out) unless Dir.exist?(out)
c = Nepse::Source::MerolaganiHistoryClient.new
symbols = [ "NEPSE" ] + Stock.active.where(security_type: "Equity").order(:symbol).pluck(:symbol)
ok = failed = 0
symbols.each do |s|
  path = "#{out}/#{s}.json"
  next ok += 1 if File.exist?(path)
  r = c.fetch(s, from: Date.new(2020, 1, 1), to: Date.new(2026, 11, 13))
  bars = Array(r[:bars])
  if r[:success] && bars.any?
    File.write(path, bars.map { |b| [ b[:traded_on].iso8601, b[:open_price].to_f, b[:high_price].to_f, b[:low_price].to_f, b[:close_price].to_f, b[:volume].to_i ] }.to_json)
    ok += 1
  else
    failed += 1
  end
  sleep 0.3
rescue StandardError => e
  failed += 1
  warn "#{s}: #{e.message}"
end
puts "symbols #{symbols.size}, saved #{ok}, failed #{failed}"
