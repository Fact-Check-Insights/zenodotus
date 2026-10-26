# typed: true

class TelegramMediaSource < MediaSource
  attr_reader(:url, :invalid_url)

  # Limit all urls to the host below
  #
  # @return [String] or [Array] of [String] of valid host names
  sig { override.returns(T::Array[String]) }
  def self.valid_host_name
    ["t.me", "www.t.me", "telegram.me", "www.telegram.me"]
  end

  # Initialize the object and capture the screenshot automatically.
  #
  # @params url [String] the url of the page to be collected for archiving
  # @returns [Sting or nil] the path of the screenshot if the screenshot was saved
  sig { params(url: String).void }
  def initialize(url)
    # Verify that the url has the proper host for this source. (@valid_host is set at the top of
    # this class)
    begin
      TelegramMediaSource.check_url(url)
      TelegramMediaSource.validate_telegram_post_url(url)
    rescue MediaSource::HostError, InvalidTelegramPostUrlError
      @invalid_url = true
    end

    @url = url
  end

private

  # Validate that the url is a direct link to a Telegram post, poorly
  #
  # Public permalinks look like https://t.me/<channel>/<msgid> (with optional
  # /s/ prefix or /<thread> segment), private ones like https://t.me/c/<internal>/<msgid>.
  #
  # @note this assumes a valid url or else it'll always (usually, maybe, whatever) fail
  #
  # @!scope class
  # @!visibility private
  # @params url [String] a url to check if it's a valid Telegram post url
  # @return [Boolean] if the string validates or not
  sig { params(url: String).returns(T::Boolean) }
  def self.validate_telegram_post_url(url)
    self.valid_host_name.each do |host_name|
      return true if /https:\/\/#{host_name}\/c\/\d+\/(\d+\/)?\d+/.match?(url)
      return true if /https:\/\/#{host_name}\/(s\/)?[A-Za-z0-9_]{4,32}\/(\d+\/)?\d+/.match?(url)
    end

    raise InvalidTelegramPostUrlError, "Telegram url #{url} does not have the standard url format"
  end
end

# A class to indicate that a post url passed in is invalid
class TelegramMediaSource::InvalidTelegramPostUrlError < StandardError; end
