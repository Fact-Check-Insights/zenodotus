require "test_helper"

class BlueskyMediaSourceTest < ActiveSupport::TestCase
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

  test "a non bluesky_url raises an error" do
    ims = BlueskyMediaSource.new("https://www.example.com")
    assert ims.invalid_url
  end

  test "an invalid bluesky post url raises error" do
    ims = BlueskyMediaSource.new("https://bsky.app/profile/maldita.es")
    assert ims.invalid_url
  end

  test "initializing returns an object" do
    assert_not_nil BlueskyMediaSource.new("https://bsky.app/profile/maldita.es/post/3l5xyzabcde")
  end

  test "extracting creates a bluesky post object" do
    bluesky_post_hash = BlueskyMediaSource.extract("https://bsky.app/profile/maldita.es/post/3l5xyzabcde", MediaSource::ScrapeType::Bluesky, true, initiated_from: Scrape.initiated_froms[:site])
    assert_not bluesky_post_hash.empty?
  end

  test "extracting without force returns true" do
    bluesky_post_response = BlueskyMediaSource.extract("https://bsky.app/profile/maldita.es/post/3l5xyzabcde", MediaSource::ScrapeType::Bluesky, false, initiated_from: Scrape.initiated_froms[:site])
    assert bluesky_post_response
  end

  test "a bad url fails validation" do
    assert BlueskyMediaSource.validate_bluesky_post_url("https://bsky.app/profile/maldita.es/post/3l5xyzabcde")
    assert_raises BlueskyMediaSource::InvalidBlueskyPostUrlError do
      BlueskyMediaSource.send(:validate_bluesky_post_url, "https://bsky.app/")
    end
  end
end
