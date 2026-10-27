require "test_helper"

class Sources::BlueskyPostTest < ActiveSupport::TestCase
  include Minitest::Hooks
  include TransactionalBeforeAll
  include ActiveJob::TestHelper

  def before_all
    @@bluesky_post = BlueskyMediaSource.extract("https://bsky.app/profile/maldita.es/post/3l5xyzabcde", MediaSource::ScrapeType::Bluesky, true, initiated_from: 0)["scrape_result"]
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

  test "can create Bluesky post" do
    archive_item = Sources::BlueskyPost.create_from_bluesky_hash(@@bluesky_post).first
    assert_not_nil archive_item
    assert_kind_of ArchiveItem, archive_item

    assert_equal @@bluesky_post.first["post"]["text"], archive_item.bluesky_post.text
    assert_equal @@bluesky_post.first["id"], archive_item.bluesky_post.bluesky_id
    assert_equal @@bluesky_post.first["id"], archive_item.service_id
    assert_equal @@bluesky_post.first["post"]["url"], archive_item.bluesky_post.url
    assert_equal @@bluesky_post.first["post"]["url"], archive_item.url

    assert_not_nil archive_item.bluesky_post.author
    assert_equal "did:plc:abc123", archive_item.bluesky_post.author.service_id
    assert_not_nil archive_item.bluesky_post.images
  end

  test "can create Bluesky post with video" do
    bluesky_video_post = BlueskyMediaSource.extract("https://bsky.app/profile/maldita.es/post/3l5videoabc", MediaSource::ScrapeType::Bluesky, true, initiated_from: Scrape.initiated_froms[:site])["scrape_result"]
    archive_item = Sources::BlueskyPost.create_from_bluesky_hash(bluesky_video_post).first
    assert_not_nil archive_item
    assert_not_nil archive_item.bluesky_post.videos
  end

  test "can create from Bluesky url" do
    assert_not_nil Sources::BlueskyPost.create_from_url!("https://bsky.app/profile/maldita.es/post/3l5xyzabcde", initiated_from: Scrape.initiated_froms[:site])
  end

  test "can create from Bluesky url using ActiveJob" do
    assert_enqueued_jobs 0
    assert Sources::BlueskyPost.create_from_url("https://bsky.app/profile/maldita.es/post/3l5xyzabcde")
    assert_enqueued_jobs 1

    assert_nothing_raised do
      perform_enqueued_jobs
    end
  end

  test "can create two Bluesky posts from same author" do
    bluesky_post2 = BlueskyMediaSource.extract("https://bsky.app/profile/maldita.es/post/3l5videoabc", MediaSource::ScrapeType::Bluesky, true, initiated_from: Scrape.initiated_froms[:site])["scrape_result"]
    archive_item = Sources::BlueskyPost.create_from_bluesky_hash(@@bluesky_post).first.bluesky_post
    archive_item2 = Sources::BlueskyPost.create_from_bluesky_hash(bluesky_post2).first.bluesky_post
    assert_equal archive_item.author, archive_item2.author
  end

  test "assert_url_can_be_checked" do
    assert Sources::BlueskyPost.can_handle_url?("https://bsky.app/profile/maldita.es/post/3l5xyzabcde")

    assert_not Sources::BlueskyPost.can_handle_url?("https://bsky.app/profile/maldita.es")
    assert_not Sources::BlueskyPost.can_handle_url?("https://www.tiktok.com/@guess/video/7091753416032128299")
  end
end
