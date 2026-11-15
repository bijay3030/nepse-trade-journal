require "json"
DIR = ENV.fetch("STUDY_DIR", "tmp/research")
WIN, LOSS, H = 0.10, 0.07, 40
lb = ->(s) { JSON.parse(File.read("#{DIR}/history/#{s}.json")) }
nepse = lb.("NEPSE"); nc = nepse.map { _1[4] }
sma = ->(v, n) { v.each_index.map { |i| i >= n - 1 ? v[(i - n + 1)..i].sum / n : nil } }
ns = sma.(nc, 200)
reg = {}; nepse.each_with_index { |b, i| s, t = ns[i], (i >= 20 ? ns[i - 20] : nil); reg[b[0]] = s.nil? || t.nil? ? "unknown" : (b[4] > s && s > t ? "bull" : (b[4] < s && s < t ? "bear" : "sideways")) }
puts "NEPSE regime share of sessions: " + reg.values.tally.transform_values { (_1 * 100.0 / reg.size).round }.to_s
puts "NEPSE regime by year: " + nepse.group_by { _1[0][0, 4] }.transform_values { |bs| bs.map { reg[_1[0]] }.tally.max_by(&:last).first }.to_s
out = Hash.new { |h, k| h[k] = Hash.new { |x, y| x[y] = Hash.new(0) } }
Dir.children("#{DIR}/history").each do |f|
  next if f == "NEPSE.json"
  b = lb.(f.delete_suffix(".json")); next if b.size < 260
  c = b.map { _1[4] }; next if c.any? { !_1.positive? }
  h = b.map { |x| [ x[2], x[4] ].max }; l = b.map { |x| [ x[3].positive? ? x[3] : x[4], x[4] ].min }; v = b.map { _1[5].to_f }
  (20...(c.size - H)).step(3) do |i|
    t20 = (0...20).sum { |k| c[i - k] * v[i - k] } / 20; next if t20 < 2_000_000
    { up: [ WIN, LOSS ], down: [ LOSS, WIN ] }.each do |dir, (u, d)|
      res = :none
      ((i + 1)..(i + H)).each do |j|
        uh = h[j] >= c[i] * (1 + u); dh = l[j] <= c[i] * (1 - d)
        if dir == :up then res = :loss if dh; res = :win if uh && !dh
        else res = :loss if uh; res = :win if dh && !uh end
        break unless res == :none
      end
      [ "all", "regime:#{reg[b[i][0]] || 'unknown'}", "year:#{b[i][0][0, 4]}" ].each { out[dir][_1][res] += 1 }
    end
  end
end
fmt = ->(x) { t = x.values.sum; t.zero? ? "-" : format("%5.1f%%/%5.1f%% n=%d", x[:win] * 100.0 / t, x[:loss] * 100.0 / t, t) }
%i[up down].each { |d| puts "BASELINE #{d == :up ? 'buy any day (+10 before -7)' : 'warn any day (-10 before +7)'}"; out[d].keys.sort.each { |k| puts "  #{k.ljust(16)} #{fmt.(out[d][k])}" } }
rows = JSON.parse(File.read("#{DIR}/turn_study.json"))
pick = [ "EMA 5/20", "EMA 9/21 *", "EMA 21/50 *", "HMA 21 *", "HMA 55", "ALMA 9 *", "Aroon 25 *", "Aroon25 Up>=70 *", "9/21 + Aroon25>=70", "21/50 + HMA21 up" ]
keys = %w[regime:bull regime:sideways regime:bear volume>=1.5x volume<1.5x] + [ "stock above 200d", "stock below 200d", "beating NEPSE (3m)", "lagging NEPSE (3m)" ]
puts "\nBOTTOM signals: win% (+10 before -7) by scenario"
puts format("%-20s", "setting") + keys.map { _1.sub("regime:", "").sub(" (3m)", "")[0, 12].rjust(13) }.join
rows.select { pick.include?(_1["setting"]) }.each do |r|
  b = r["up"]["buckets"]
  puts format("%-20s", r["setting"]) + keys.map { |k| (x = b[k]) && x["n"] >= 50 ? format("%5.1f(%5d)", x["win_pct"], x["n"]).rjust(13) : "-".rjust(13) }.join
end
puts "\nBOTTOM signals: win% by year"
yrs = (2020..2026).map { "year:#{_1}" }
puts format("%-20s", "setting") + yrs.map { _1[5, 4].rjust(8) }.join
rows.select { pick.include?(_1["setting"]) }.each { |r| b = r["up"]["buckets"]; puts format("%-20s", r["setting"]) + yrs.map { |k| (x = b[k]) && x["n"] >= 30 ? format("%6.1f", x["win_pct"]).rjust(8) : "-".rjust(8) }.join }
puts "\nTOP signals (warnings): right% (-10 before +7) by regime"
rows.select { pick.include?(_1["setting"]) }.each { |r| b = r["down"]["buckets"]; puts format("%-20s", r["setting"]) + %w[regime:bull regime:sideways regime:bear].map { |k| (x = b[k]) ? format("%5.1f(%5d)", x["win_pct"], x["n"]).rjust(13) : "-".rjust(13) }.join }
