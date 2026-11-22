require "did_you_mean"

module Events
  # Finds the listed company an announcement is about. Titles name it first ("Nabil Bank
  # Limited has ...") or after "promoter(s) of" ("The existing promoter of Nepal Finance
  # Limited is selling ..."). Names are compared without punctuation, spaces and the
  # words Limited / Ltd / Company, so "Micro Finance" matches "Microfinance"; the longest
  # match wins ("Nabil Investment Banking" isn't "Nabil Bank"). Failing that, the title's
  # company part is compared by spelling (Jaro-Winkler at least SIMILARITY), which catches
  # small differences in our stored names.
  class CompanyMatcher
    SUFFIX = /\b(limited|ltd|company|co|the|pvt|private)\b/
    VERB = /\s(has|have|is|are|was|will|announce\w*|publish\w*|post\w*)\s/i
    SIMILARITY = 0.95

    def initialize(stocks = Stock.where(security_type: "Equity"))
      @names = stocks.pluck(:id, :name).filter_map { |id, name| (key = compact(name)).length >= 6 ? [ key, id ] : nil }
                     .sort_by { -_1.first.length }
    end

    def stock_id(title)
      subject = subject(title)
      key = compact(subject)
      exact = @names.find { |name, _| key == name || key.start_with?(name) }
      return exact.last if exact

      best = @names.max_by { |name, _| DidYouMean::JaroWinkler.distance(name, key) }
      best && DidYouMean::JaroWinkler.distance(best.first, key) >= SIMILARITY ? best.last : nil
    end

    private

    # The words naming the company: after "promoter(s) of", up to the first verb.
    def subject(title)
      text = title.to_s.squish
      text = Regexp.last_match(1) if text =~ /promoters?\s+of\s+(.+)/i
      text.split(VERB).first.to_s
    end

    def compact(text) = text.to_s.downcase.gsub(/[^a-z0-9 ]/, " ").gsub(SUFFIX, " ").delete(" ")
  end
end
