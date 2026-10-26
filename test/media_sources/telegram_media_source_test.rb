require "test_helper"

class TelegramMediaSourceTest < ActiveSupport::TestCase
  include Minitest::Hooks
  include TransactionalBeforeAll

  def around
    AwsS3Downloader.stub(:download_file_in_s3_received_from_hypatia, S3_MOCK_STUB) do
      super
    end
  end

  def after_all
    if File.exist?("tmp") && File.directory?("tmp")
      FileUtils.rm_r("tmp")
    end
  end

  test "a non telegram_url raises an error" do
    ims = TelegramMediaSource.new("https://www.example.com")
    assert ims.invalid_url
  end

  test "an invalid telegram post url raises error" do
    ims = TelegramMediaSource.new("https://t.me/ConfirmadoTransparencia")
    assert ims.invalid_url
  end

  test "initializing returns an object" do
    assert_not_nil TelegramMediaSource.new("https://t.me/ConfirmadoTransparencia/1764")
  end

  test "extracting creates a telegram post object" do
    telegram_post_hash = TelegramMediaSource.extract("https://t.me/ConfirmadoTransparencia/1764", MediaSource::ScrapeType::Telegram, true, initiated_from: Scrape.initiated_froms[:site])
    assert_not telegram_post_hash.empty?
  end

  test "extracting without force returns true" do
    telegram_post_response = TelegramMediaSource.extract("https://t.me/ConfirmadoTransparencia/1764", MediaSource::ScrapeType::Telegram, false, initiated_from: Scrape.initiated_froms[:site])
    assert telegram_post_response
  end

  test "a bad url fails validation" do
    assert TelegramMediaSource.validate_telegram_post_url("https://t.me/ConfirmadoTransparencia/1764")
    assert_raises TelegramMediaSource::InvalidTelegramPostUrlError do
      TelegramMediaSource.send(:validate_telegram_post_url, "https://t.me/")
    end
  end
end
