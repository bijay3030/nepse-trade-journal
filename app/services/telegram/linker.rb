module Telegram
  # Links a user's Telegram chat without a public webhook:
  #
  # 1. start(user) gives the user a short one-time code, also in a t.me deep link.
  # 2. Pressing Start from the link sends "/start <code>" to the bot. Telegram often
  #    drops the code (a forwarded link, or a chat opened before), so sending the
  #    code itself as a message works too.
  # 3. poll (every minute, or when the user clicks "Check") reads the bot's new
  #    messages and links the chat whose code matches. "/stop" unlinks.
  #
  # The update offset is stored (AppSetting) so a message is handled once; otherwise
  # an old "/stop" could unlink a chat that was linked again since.
  class Linker
    CODE_TTL = 30.minutes
    # Easy to read and type on a phone: no 0/O, 1/I/L.
    CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".chars.freeze
    CODE_LENGTH = 8
    CODE_PATTERN = /\A(?:\/(?:start|link)\s+)?([A-Za-z0-9]{#{CODE_LENGTH}})\z/
    HOW_TO_CONNECT = "To connect, open NEPSE Trade Journal → Settings → Telegram, click Connect Telegram, " \
                     "and send me the 8-character code it shows (for example K7M2QX9P).".freeze
    OFFSET_KEY = "telegram_update_offset".freeze

    # { code:, bot_username:, url: }
    def self.start(user, client: Client.new)
      code = Array.new(CODE_LENGTH) { CODE_ALPHABET[SecureRandom.random_number(CODE_ALPHABET.size)] }.join
      user.update!(telegram_link_token: code, telegram_link_expires_at: CODE_TTL.from_now)
      bot = client.bot_username
      { code: code, bot_username: bot, url: "https://t.me/#{bot}?start=#{code}" }
    end

    def self.poll(client: Client.new) = new(client).poll

    def self.unlink!(user)
      user.update!(telegram_chat_id: nil, telegram_username: nil, telegram_link_token: nil, telegram_link_expires_at: nil)
    end

    def initialize(client)
      @client = client
    end

    # Returns the number of chats linked or unlinked.
    def poll
      updates = @client.get_updates(offset: AppSetting.get(OFFSET_KEY)&.to_i)
      changed = updates.count { handle(_1["message"]) }
      AppSetting.set(OFFSET_KEY, updates.last["update_id"] + 1) if updates.any?
      changed
    end

    private

    def handle(message)
      return false unless message && message.dig("chat", "type") == "private"

      chat_id = message.dig("chat", "id").to_s
      text = message["text"].to_s.strip
      case text
      when CODE_PATTERN then link(Regexp.last_match(1).upcase, chat_id, message.dig("from", "username"))
      when %r{\A/stop\b} then stop(chat_id)
      when %r{\A/start\b} then reply(chat_id, HOW_TO_CONNECT) && false
      else false
      end
    end

    def link(code, chat_id, username)
      user = User.find_by(telegram_link_token: code)
      unless user && user.telegram_link_expires_at&.future?
        reply(chat_id, "That code isn't valid or has expired. Click Connect Telegram in the app's Settings for a new one.")
        return false
      end

      # A chat belongs to one account.
      User.where(telegram_chat_id: chat_id).where.not(id: user.id).find_each { Linker.unlink!(_1) }
      user.update!(telegram_chat_id: chat_id, telegram_username: username, telegram_link_token: nil, telegram_link_expires_at: nil)
      reply(chat_id, "Connected to NEPSE Trade Journal (#{ERB::Util.html_escape(user.email)}). You'll get entry-zone messages here. Send /stop to disconnect.")
      true
    end

    def stop(chat_id)
      users = User.where(telegram_chat_id: chat_id).to_a
      users.each { Linker.unlink!(_1) }
      reply(chat_id, "Disconnected. You won't get messages here any more.") if users.any?
      users.any?
    end

    def reply(chat_id, text)
      @client.send_message(chat_id, text)
      true
    rescue Error => e
      Rails.logger.warn("Telegram reply failed: #{e.message}")
      false
    end
  end
end
