module Telegram
  class Error < StandardError
    attr_reader :code

    def initialize(message, code: nil)
      super(message)
      @code = code
    end

    # The user blocked the bot or the chat is gone: stop sending to it.
    def chat_unreachable? = code == 403 || (code == 400 && message.match?(/chat not found/i))
  end

  # Minimal Telegram Bot API client. The token comes from TELEGRAM_BOT_TOKEN or the
  # telegram.bot_token credential; without one, Telegram is simply off.
  #
  # The credentials are shared with development, and two apps polling one bot
  # steal each other's messages (and both send alerts), so development ignores the
  # credential unless TELEGRAM_IN_DEVELOPMENT=true. TELEGRAM_BOT_TOKEN always works,
  # e.g. with a separate test bot, as long as it has a bot token's shape
  # ("<bot id>:<secret>"): a malformed one (a placeholder or a pasted fragment) is
  # ignored with a warning, since Telegram would answer every call with "Not Found".
  class Client
    BASE_URL = "https://api.telegram.org"
    TIMEOUT = 10
    TOKEN_FORMAT = /\A\d{6,}:[A-Za-z0-9_-]{30,}\z/

    def self.token
      env_token || (credential_token if !Rails.env.development? || ENV["TELEGRAM_IN_DEVELOPMENT"] == "true")
    end

    def self.env_token
      value = ENV["TELEGRAM_BOT_TOKEN"].to_s.strip
      return if value.empty?
      return value if value.match?(TOKEN_FORMAT)

      unless @warned_malformed
        Rails.logger.warn("TELEGRAM_BOT_TOKEN is set but isn't a bot token (expected <bot id>:<secret>); ignoring it.")
        @warned_malformed = true
      end
      nil
    end

    def self.credential_token = Rails.application.credentials.dig(:telegram, :bot_token)
    def self.configured? = token.present?

    def initialize(token: self.class.token)
      raise Error, "TELEGRAM_BOT_TOKEN is not set" if token.blank?

      @token = token
    end

    def send_message(chat_id, text)
      call("sendMessage", chat_id: chat_id, text: text, parse_mode: "HTML", disable_web_page_preview: true)
    end

    def get_updates(offset: nil)
      call("getUpdates", { offset: offset, timeout: 0, allowed_updates: [ "message" ] }.compact)
    end

    # The bot's @username, for the t.me link. Cached: it doesn't change.
    def bot_username
      Rails.cache.fetch("telegram:bot_username:#{@token.split(':').first}", expires_in: 1.day) { call("getMe")["username"] }
    end

    private

    def call(method, params = {})
      response = HTTParty.post("#{BASE_URL}/bot#{@token}/#{method}", body: params.to_json,
                                                                       headers: { "Content-Type" => "application/json" }, timeout: TIMEOUT)
      body = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
      raise Error.new(body["description"] || "Telegram #{method} failed (HTTP #{response.code})", code: response.code) unless body["ok"]

      body["result"]
    rescue HTTParty::Error, SocketError, Timeout::Error, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
      # Never include the URL: it contains the token.
      raise Error, "Telegram #{method} failed: #{e.class}"
    end
  end
end
