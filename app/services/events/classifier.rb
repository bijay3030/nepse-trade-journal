module Events
  # Rates an announcement for the share price with fixed rules, so every rating has a
  # plain reason. Bonus, cash dividend and rights figures come structured from Chukul;
  # everything else is read from ShareSansar's announcement titles. The typical price
  # reaction around book closes is measured separately (Events::BookCloseStudy).
  #
  #   positive  bonus or cash dividend proposed; profit up on the same quarter last year;
  #             a promoter share sale cancelled; a credit rating upgraded
  #   negative  a net loss or
  #             profit down on last year; promoter shares for sale or their lock-in
  #             ending; trading halted or suspended, or a regulator's penalty;
  #             a rating downgraded; no dividend
  #   mixed     rights issues (they dilute holders and the price adjusts down at book
  #             close, yet on NEPSE since 2020 adjusted prices rose on average around
  #             rights book closes: Events::BookCloseStudy); mergers and acquisitions
  #   neutral   AGMs without dividend news, book-close notices, issues, management news
  #
  # Rule checks, not advice.
  module Classifier
    BIG_BONUS_PCT = 10.0

    module_function

    # Structured: { bonus:, cash:, book_close_on:, year: } from Chukul's bonus feed.
    def dividend(bonus:, cash:, book_close_on: nil, year: nil)
      bonus = bonus.to_f
      cash = cash.to_f
      parts = []
      parts << "#{fmt(bonus)}% bonus shares" if bonus.positive?
      parts << "#{fmt(cash)}% cash dividend" if cash.positive?
      closes = book_close_on ? " Book close #{book_close_on.strftime('%-d %b %Y')}: the price adjusts down by the bonus and cash on that day." : ""
      if parts.empty?
        return result("cash_dividend", "negative", "No dividend for #{year || 'the year'}.", important: false, data: { bonus: 0, cash: 0 })
      end

      kind = bonus.positive? ? "bonus" : "cash_dividend"
      reason = "#{parts.join(' and ')} proposed#{year ? " for #{year}" : ''}. Prices often rise into the book close.#{closes}"
      result(kind, "positive", reason, important: bonus >= BIG_BONUS_PCT || cash >= BIG_BONUS_PCT, data: { bonus: bonus, cash: cash })
    end

    # Structured: { right:, book_close_on: } from Chukul's rights feed (percent of holdings).
    def rights(right:, book_close_on: nil)
      ratio = right.to_f
      closes = book_close_on ? " Book close #{book_close_on.strftime('%-d %b %Y')}." : ""
      result("rights", "mixed",
             "#{fmt(ratio)}% rights shares (#{ratio_text(ratio)}): new shares at Rs 100 dilute holders and the price adjusts down at book close, " \
             "though on NEPSE since 2020 prices rose on average around rights book closes.#{closes}",
             important: true, data: { right: ratio })
    end

    # An announcement title; previous: the same company's last result event (for profit change).
    def title(text, previous_result: nil)
      t = text.to_s.squish
      case t
      when /posted a net (profit|loss) of (?:Rs\.?\s*)?([\d,.]+)\s*(million|billion|crore|lakh)?/i
        results(t, Regexp.last_match, previous_result)
      when /cancel\w*.{0,60}(sale|auction) of promoter share/i
        result("promoter_sale", "positive", "Promoter share sale cancelled: less supply coming to market.")
      when /promoter/i
        if t.match?(/lock.?in/i)
          result("promoter_lockin", "negative", "Promoter shares' lock-in ending: more shares can be sold.", important: true)
        elsif t.match?(/sale|sell|auction/i)
          result("promoter_sale", "negative", "Promoter shares for sale: extra supply, and insiders choosing to sell.", important: true)
        else
          result("promoter_sale", "neutral", "Promoter share notice.")
        end
      when /right share|rights? issue|\bright\b.{0,20}share/i
        if t.match?(/allot|result|list/i)
          result("rights", "neutral", "Rights shares allotted or listed: the new shares can now trade.")
        else
          result("rights", "mixed", "Rights shares: dilution and a price adjustment at book close, though prices often rose around past rights book closes.", important: true)
        end
      when /bonus share|bonus/i
        result("bonus", "positive", "Bonus shares: prices often rise into the book close, then adjust down by the bonus.", important: true)
      when /\bmerg|acquisition|acquire/i
        result("merger", "mixed", "Merger or acquisition: the swap ratio and terms decide whether it helps holders.", important: true)
      when /halt|suspend|penalt|fined|action against|show.?cause|delist/i
        result("regulatory", "negative", "Regulatory action or trading halt.", important: true)
      when /credit rating|rating/i
        if t.match?(/upgrad/i) then result("credit_rating", "positive", "Credit rating upgraded.")
        elsif t.match?(/downgrad/i) then result("credit_rating", "negative", "Credit rating downgraded.", important: true)
        else result("credit_rating", "neutral", "Credit rating reaffirmed or assigned.")
        end
      when /book clos/i
        result("book_close", "neutral", "Book close: entitlements are fixed and the price adjusts for any bonus or rights.", important: true)
      when /\b(AGM|SGM|annual general meeting|special general meeting)\b/i
        if t.match?(/dividend|bonus/i)
          result("agm", "positive", "AGM with a dividend or bonus on the agenda.")
        else
          result("agm", "neutral", "AGM or SGM notice.")
        end
      when /\b(IPO|FPO|auction|debenture|mutual fund)\b/i
        result("issue", "neutral", "Share or debenture issue notice.")
      when /\b(CEO|chairman|appoint|resign|director|board)\b/i
        result("management", "neutral", "Management or board change.")
      else
        result("other", "neutral", "Company notice.")
      end
    end

    def results(text, match, previous)
      loss = match[1].casecmp("loss").zero?
      amount = match[2].delete(",").to_f * { "billion" => 1000.0, "crore" => 10.0, "lakh" => 0.1 }.fetch(match[3].to_s.downcase, 1.0)
      amount = -amount if loss
      quarter = text[/(\d)(?:st|nd|rd|th) quarter/i, 1]&.to_i
      year = text[/fiscal year (\d{4}\/\d{2})/i, 1]
      data = { net_profit_m: amount.round(2), quarter: quarter, fiscal_year: year }
      prev = previous&.data&.dig("net_profit_m")
      if prev
        change = prev.zero? ? nil : ((amount - prev) / prev.abs * 100).round(1)
        data[:previous_net_profit_m] = prev
        data[:change_pct] = change
        word = amount > prev ? "up" : "down"
        impact = amount > prev && amount.positive? ? "positive" : "negative"
        return result("results", impact, "Net #{loss ? 'loss' : 'profit'} Rs #{fmt(amount.abs)}M, #{word} from Rs #{fmt(prev)}M#{change ? " (#{change.positive? ? '+' : ''}#{change}%)" : ''} in the comparable report.", data: data)
      end

      if loss
        result("results", "negative", "Net loss of Rs #{fmt(amount.abs)}M#{quarter ? " in Q#{quarter}" : ''}.", data: data)
      else
        result("results", "neutral", "Net profit of Rs #{fmt(amount)}M#{quarter ? " in Q#{quarter}" : ''}; no earlier report stored to compare.", data: data)
      end
    end

    def ratio_text(pct) = pct >= 100 ? "#{fmt(pct / 100)}:1" : "1 for every #{fmt(100 / pct)} held"
    def fmt(value) = format("%g", value.to_f.round(2))

    def result(kind, impact, reason, important: false, data: {})
      { kind: kind, impact: impact, reason: reason, important: important, data: data }
    end
  end
end
