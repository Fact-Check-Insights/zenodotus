require "test_helper"

class Sources::TelegramPostTest < ActiveSupport::TestCase
  include Minitest::Hooks
  include TransactionalBeforeAll
  include ActiveJob::TestHelper

  def before_all
    @@telegram_post = TelegramMediaSource.extract("https://t.me/ConfirmadoTransparencia/1764", MediaSource::ScrapeType::Telegram, true, initiated_from: 0)["scrape_result"]
  end

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

  test "can create Telegram post" do
    archive_item = Sources::TelegramPost.create_from_telegram_hash(@@telegram_post).first
    assert_not_nil archive_item
    assert_kind_of ArchiveItem, archive_item

    assert_equal @@telegram_post.first["post"]["text"], archive_item.telegram_post.text
    assert_equal @@telegram_post.first["id"], archive_item.telegram_post.telegram_id
    assert_equal @@telegram_post.first["id"], archive_item.service_id
    assert_equal @@telegram_post.first["post"]["url"], archive_item.telegram_post.url
    assert_equal @@telegram_post.first["post"]["url"], archive_item.url

    assert_not_nil archive_item.telegram_post.author
    assert_equal "ConfirmadoTransparencia", archive_item.telegram_post.author.service_id
  end

  test "can create from Telegram url" do
    assert_not_nil Sources::TelegramPost.create_from_url!("https://t.me/ConfirmadoTransparencia/1764", initiated_from: Scrape.initiated_froms[:site])
  end

  test "can create from Telegram url using ActiveJob" do
    assert_enqueued_jobs 0
    assert Sources::TelegramPost.create_from_url("https://t.me/ConfirmadoTransparencia/1764")
    assert_enqueued_jobs 1

    assert_nothing_raised do
      perform_enqueued_jobs
    end
  end

  test "assert_url_can_be_checked" do
    assert Sources::TelegramPost.can_handle_url?("https://t.me/ConfirmadoTransparencia/1764")
    assert Sources::TelegramPost.can_handle_url?("https://t.me/c/1234567890/55")

    assert_not Sources::TelegramPost.can_handle_url?("https://t.me/ConfirmadoTransparencia")
    assert_not Sources::TelegramPost.can_handle_url?("https://bsky.app/profile/maldita.es/post/3l5xyzabcde")
  end
end
