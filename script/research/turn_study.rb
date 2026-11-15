require "json"
DIR = ENV.fetch("STUDY_DIR", "tmp/research")
T = Indicators::Trend
SWING = 0.15
WIN, LOSS, HORIZON = 0.10, 0.07, 40
MIN_TURNOVER = 2_000_000

load_bars = ->(sym) { JSON.parse(File.read("#{DIR}/history/#{sym}.json")) } # [date, o, h, l, c, v]
nepse = load_bars.("NEPSE")
n_close = nepse.map { _1[4] }
sma = ->(v, n) { v.each_index.map { |i| i >= n - 1 ? v[(i - n + 1)..i].sum / n : nil } }
n_sma200 = sma.(n_close, 200)
regime_by_date = {}
nepse.each_with_index do |b, i|
  s, s_then = n_sma200[i], (i >= 20 ? n_sma200[i - 20] : nil)
  regime_by_date[b[0]] = if s.nil? || s_then.nil? then "unknown"
                         elsif b[4] > s && s > s_then then "bull"
                         elsif b[4] < s && s < s_then then "bear"
                         else "sideways"
                         end
end
n_index = nepse.each_with_index.to_h { |b, i| [ b[0], i ] }

# Zigzag on closes: alternating bottoms/tops where each leg moves >= SWING.
def zigzag(c, swing)
  pivots = []
  dir = nil; ext_i = 0
  (1...c.size).each do |i|
    if dir.nil?
      if c[i] >= c[ext_i] * (1 + swing) then pivots << [ ext_i, :bottom ]; dir = :up; ext_i = i
      elsif c[i] <= c[ext_i] * (1 - swing) then pivots << [ ext_i, :top ]; dir = :down; ext_i = i
      else ext_i = i if (c[i] < c[ext_i] && c[i] < c[0]) || (c[i] > c[ext_i] && c[i] > c[0])
      end
    elsif dir == :up
      if c[i] > c[ext_i] then ext_i = i
      elsif c[i] <= c[ext_i] * (1 - swing) then pivots << [ ext_i, :top ]; dir = :down; ext_i = i
      end
    else
      if c[i] < c[ext_i] then ext_i = i
      elsif c[i] >= c[ext_i] * (1 + swing) then pivots << [ ext_i, :bottom ]; dir = :up; ext_i = i
      end
    end
  end
  pivots
end

cross = ->(a, b) { ->(i) { a[i] && b[i] ? a[i] > b[i] : nil } }
SETTINGS = {
  "EMA 5/20" => ->(s) { cross.(s[:e5], s[:e20]) },
  "EMA 9/21 *" => ->(s) { cross.(s[:e9], s[:e21]) },
  "EMA 10/30" => ->(s) { cross.(s[:e10], s[:e30]) },
  "EMA 20/50" => ->(s) { cross.(s[:e20], s[:e50]) },
  "EMA 21/50 *" => ->(s) { cross.(s[:e21], s[:e50]) },
  "EMA stack 9>21>50 *" => ->(s) { ->(i) { s[:e9][i] && s[:e50][i] ? s[:e9][i] > s[:e21][i] && s[:e21][i] > s[:e50][i] : nil } },
  "HMA 9" => ->(s) { m = s[:h9]; ->(i) { i > 0 && m[i] && m[i - 1] ? m[i] > m[i - 1] : nil } },
  "HMA 21 *" => ->(s) { m = s[:h21]; ->(i) { i > 0 && m[i] && m[i - 1] ? m[i] > m[i - 1] : nil } },
  "HMA 55" => ->(s) { m = s[:h55]; ->(i) { i > 0 && m[i] && m[i - 1] ? m[i] > m[i - 1] : nil } },
  "ALMA 9 *" => ->(s) { cross.(s[:c], s[:a9]) },
  "ALMA 21" => ->(s) { cross.(s[:c], s[:a21]) },
  "ALMA 50" => ->(s) { cross.(s[:c], s[:a50]) },
  "Aroon 14" => ->(s) { cross.(s[:u14], s[:d14]) },
  "Aroon 25 *" => ->(s) { cross.(s[:u25], s[:d25]) },
  "Aroon 50" => ->(s) { cross.(s[:u50], s[:d50]) },
  "Aroon25 Up>=70 *" => ->(s) { ->(i) { s[:u25][i] ? s[:u25][i] >= 70 : nil } },
  "9/21 + Aroon25>=70" => ->(s) { ->(i) { s[:e9][i] && s[:u25][i] ? s[:e9][i] > s[:e21][i] && s[:u25][i] >= 70 : nil } },
  "21/50 + HMA21 up" => ->(s) { m = s[:h21]; ->(i) { s[:e50][i] && i > 0 && m[i] && m[i - 1] ? s[:e21][i] > s[:e50][i] && m[i] > m[i - 1] : nil } },
}

stats = Hash.new { |h, k| h[k] = Hash.new { |x, y| x[y] = Hash.new(0) } } # stats[setting][dir][key]
lags = Hash.new { |h, k| h[k] = Hash.new { |x, y| x[y] = [] } }
left = Hash.new { |h, k| h[k] = Hash.new { |x, y| x[y] = [] } }
outcome = Hash.new { |h, k| h[k] = Hash.new { |x, y| x[y] = Hash.new { |z, w| z[w] = Hash.new(0) } } } # [setting][dir][bucket] -> win/loss/none
swings = { up: 0, down: 0 }
years = Hash.new { |h, k| h[k] = Hash.new(0) }

symbols = Dir.children("#{DIR}/history").map { _1.delete_suffix(".json") } - [ "NEPSE" ]
symbols.each do |sym|
  b = load_bars.(sym)
  next if b.size < 260

  c = b.map { _1[4] }
  next if c.any? { !_1.positive? }

  h = b.map { |x| [ x[2], x[4] ].max }; l = b.map { |x| [ x[3].positive? ? x[3] : x[4], x[4] ].min }
  v = b.map { _1[5].to_f }
  turnover20 = c.each_index.map { |i| i >= 19 ? (19.downto(0).sum { |k| c[i - k] * v[i - k] } / 20) : nil }
  vavg50 = v.each_index.map { |i| i >= 50 ? v[(i - 50)...i].sum / 50 : nil }
  s200 = sma.(c, 200)
  a14 = T.aroon(h, l, 14); a25 = T.aroon(h, l, 25); a50 = T.aroon(h, l, 50)
  s = { c: c, e5: T.ema(c, 5), e9: T.ema(c, 9), e10: T.ema(c, 10), e20: T.ema(c, 20), e21: T.ema(c, 21), e30: T.ema(c, 30), e50: T.ema(c, 50),
        h9: T.hma(c, 9), h21: T.hma(c, 21), h55: T.hma(c, 55), a9: T.alma(c, 9), a21: T.alma(c, 21), a50: T.alma(c, 50),
        u14: a14[:up], d14: a14[:down], u25: a25[:up], d25: a25[:down], u50: a50[:up], d50: a50[:down] }

  piv = zigzag(c, SWING)
  legs = piv.each_cons(2).map { |(i, t), (j, _)| { from: i, to: j, dir: t == :bottom ? :up : :down } }
  legs.each { swings[_1[:dir]] += 1 }

  SETTINGS.each do |name, build|
    cond = build.(s)
    n = c.size
    on_up = (1...n).select { |i| cond.(i) == true && cond.(i - 1) == false }
    on_dn = (1...n).select { |i| cond.(i) == false && cond.(i - 1) == true }
    { up: on_up, down: on_dn }.each do |dir, ons|
      # turning-point capture: first signal of this direction inside each leg of that direction
      legs.select { _1[:dir] == dir }.each do |leg|
        stats[name][dir][:legs] += 1
        sig = ons.find { |i| i >= leg[:from] && i < leg[:to] }
        next unless sig

        stats[name][dir][:caught] += 1
        lags[name][dir] << sig - leg[:from]
        move = c[leg[:to]] - c[leg[:from]]
        left[name][dir] << (c[leg[:to]] - c[sig]) / move # share of the swing still ahead
      end
      # trade outcome: +10% before -7% (up) / -10% before +7% (down) within HORIZON
      ons.each do |i|
        next unless turnover20[i] && turnover20[i] >= MIN_TURNOVER

        res = :none
        ((i + 1)..[ i + HORIZON, n - 1 ].min).each do |j|
          up_hit = dir == :up ? h[j] >= c[i] * (1 + WIN) : h[j] >= c[i] * (1 + LOSS)
          dn_hit = dir == :up ? l[j] <= c[i] * (1 - LOSS) : l[j] <= c[i] * (1 - WIN)
          if dir == :up
            res = :loss if dn_hit
            res = :win if up_hit && !dn_hit
          else
            res = :loss if up_hit
            res = :win if dn_hit && !up_hit
          end
          break unless res == :none
        end
        next if i + HORIZON >= n && res == :none

        reg = regime_by_date[b[i][0]] || "unknown"
        buckets = [ "all", "regime:#{reg}", "year:#{b[i][0][0, 4]}" ]
        if dir == :up
          vr = vavg50[i] ? v[i] / vavg50[i] : nil
          buckets << (vr && vr >= 1.5 ? "volume>=1.5x" : "volume<1.5x") if vr
          buckets << (s200[i] && c[i] > s200[i] ? "stock above 200d" : "stock below 200d") if s200[i]
          ni = n_index[b[i][0]]
          if ni && ni >= 63 && i >= 63
            rs = (c[i] / c[i - 63] - 1) - (n_close[ni] / n_close[ni - 63] - 1)
            buckets << (rs > 0 ? "beating NEPSE (3m)" : "lagging NEPSE (3m)")
          end
        end
        buckets.each { |bk| outcome[name][dir][bk][res] += 1 }
      end
    end
  end
end

# baseline: buying any liquid stock-day
puts "swings found: #{swings}"
med = ->(a) { a.empty? ? nil : a.sort[a.size / 2] }
rows = SETTINGS.keys.map do |name|
  r = { setting: name }
  %i[up down].each do |dir|
    st = stats[name][dir]
    o = outcome[name][dir]["all"]
    total = o[:win] + o[:loss] + o[:none]
    r[dir] = {
      caught_pct: st[:legs].positive? ? (st[:caught] * 100.0 / st[:legs]).round(1) : nil,
      median_lag: med.(lags[name][dir]),
      median_left_pct: (m = med.(left[name][dir])) && (m * 100).round(0),
      signals: total,
      win_pct: total.positive? ? (o[:win] * 100.0 / total).round(1) : nil,
      loss_pct: total.positive? ? (o[:loss] * 100.0 / total).round(1) : nil,
      buckets: outcome[name][dir].to_h { |k, x| t = x[:win] + x[:loss] + x[:none]; [ k, { n: t, win_pct: t.positive? ? (x[:win] * 100.0 / t).round(1) : nil, loss_pct: t.positive? ? (x[:loss] * 100.0 / t).round(1) : nil } ] }
    }
  end
  r
end
File.write("#{DIR}/turn_study.json", JSON.pretty_generate(rows))
puts format("%-21s | %-38s | %s", "setting", "BOTTOMS: caught / lag / swing left / win-loss", "TOPS: caught / lag / drop left / right-wrong")
rows.each do |r|
  u, d = r[:up], r[:down]
  puts format("%-21s | %5s%% %3s d %4s%% %5s%%/%5s%% n=%-5s | %5s%% %3s d %4s%% %5s%%/%5s%% n=%s", r[:setting], u[:caught_pct], u[:median_lag], u[:median_left_pct], u[:win_pct], u[:loss_pct], u[:signals], d[:caught_pct], d[:median_lag], d[:median_left_pct], d[:win_pct], d[:loss_pct], d[:signals])
end
