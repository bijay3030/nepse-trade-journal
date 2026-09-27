require "cgi"

class NepsePriceService
  include HTTParty

  DEFAULT_TIMEOUT_SECONDS = 10
  DEFAULT_API_TEMPLATE = "https://nepsetty.kokomo.workers.dev/api?symbol=%{symbol}".freeze

  def initialize(symbol)
    @symbol = symbol.to_s.upcase.strip
  end

  def fetch_current
    return nil if @symbol.blank?

    response = HTTParty.get(
      api_url,
      timeout: DEFAULT_TIMEOUT_SECONDS,
      headers: request_headers,
      follow_redirects: true
    )
    return nil unless response.success?

    body = parse_body(response.body)
    payload = extract_symbol_payload(body) || extract_symbol_payload(body["data"]) || extract_symbol_payload(body["result"]) || body
    return nil unless payload.is_a?(Hash)

    last_price = number_from(payload, %w[ltp last_price lastPrice close price])
    return nil if last_price.nil?

    open_price = number_from(payload, %w[open open_price openPrice])
    high_price = number_from(payload, %w[high high_price highPrice max_price])
    low_price = number_from(payload, %w[low low_price lowPrice min_price])
    prev_close = number_from(payload, %w[previous_close prev_close prevClose previousClose])
    change_amount = number_from(payload, %w[change change_amount price_change point_change])
    change_percent = number_from(payload, %w[change_percent changePercent percent_change pChange percentageChange])
    volume = integer_from(payload, %w[volume total_traded_quantity totalTradedQuantity qty tradedShares tradedVolume])
    turnover = number_from(payload, %w[turnover total_traded_amount totalTradedAmount amount])
    total_trades = integer_from(payload, %w[total_trades totalTrades trades transactions totalTransactions])
    company_name = string_from(payload, %w[company_name companyName name title])
    raw_updated = payload["last_updated"] || payload["lastUpdated"] || payload["timestamp"] || payload["updated_at"]

    last_updated_time = parse_time(raw_updated) || Time.current

    {
      symbol: @symbol,
      company_name: company_name,
      last_price: last_price.round(2),
      open_price: open_price&.round(2),
      high_price: high_price&.round(2),
      low_price: low_price&.round(2),
      previous_close: prev_close&.round(2),
      change_amount: change_amount&.round(2),
      change_percent: (change_percent || 0.0).round(2),
      volume: volume || 0,
      turnover: turnover&.round(2),
      total_trades: total_trades || 0,
      last_updated: last_updated_time
    }
  rescue StandardError => e
    Rails.logger.warn("NepsePriceService error for #{@symbol}: #{e.message}")
    nil
  end

  private

  def api_url
    template = ENV["NEPSE_FREE_API_TEMPLATE"].presence || DEFAULT_API_TEMPLATE
    format(template, symbol: CGI.escape(@symbol))
  end

  def request_headers
    headers = {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Accept" => "application/json, text/plain, */*"
    }
    api_key = ENV["NEPSE_FREE_API_KEY"].to_s
    return headers if api_key.blank?

    header_name = ENV["NEPSE_FREE_API_KEY_HEADER"].presence || "X-API-Key"
    headers.merge(header_name => api_key)
  end

  def parse_body(raw_body)
    parsed = JSON.parse(raw_body)
    parsed.is_a?(Hash) ? parsed : { "data" => parsed }
  rescue JSON::ParserError
    {}
  end

  def extract_symbol_payload(node)
    case node
    when Array
      node.find { |item| symbol_matches?(item) }
    when Hash
      return node if symbol_matches?(node)
      nested = node.values.find { |value| value.is_a?(Hash) && symbol_matches?(value) }
      nested if nested.is_a?(Hash)
    end
  end

  def symbol_matches?(hash)
    return false unless hash.is_a?(Hash)

    raw = hash["symbol"] || hash["id"] || hash["stockSymbol"] || hash["securitySymbol"] || hash["ticker"]
    raw.to_s.upcase == @symbol
  end

  def number_from(hash, keys)
    value = keys.lazy.map { |key| hash[key] }.find { |candidate| present_number?(candidate) }
    value&.to_f
  end

  def integer_from(hash, keys)
    value = keys.lazy.map { |key| hash[key] }.find { |candidate| present_number?(candidate) }
    value&.to_i
  end

  def string_from(hash, keys)
    keys.lazy.map { |key| hash[key] }.find { |candidate| candidate.present? }&.to_s
  end

  def present_number?(value)
    return false if value.nil?

    value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
  end

  def parse_time(raw)
    return nil if raw.blank?
    Time.zone.parse(raw.to_s) rescue nil
  end
end
