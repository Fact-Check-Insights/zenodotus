# typed: ignore

require "test_helper"

class MediaVault::Api::V1::ScrapesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  INSTAGRAM_URL = "https://www.instagram.com/p/CBcqOkyDDH8/"

  def auth_headers(key = "123456789")
    { "Authorization" => "Bearer #{key}" }
  end

  test "rejects requests without an api key" do
    get media_vault_api_v1_scrapes_url
    assert_response :unauthorized
  end

  test "rejects an invalid api key" do
    get media_vault_api_v1_scrapes_url, headers: auth_headers("wrong")
    assert_response :unauthorized
  end

  test "rejects an inactive api key" do
    get media_vault_api_v1_scrapes_url, headers: auth_headers("987654321")
    assert_response :unauthorized
  end

  test "accepts the api key as a param" do
    get media_vault_api_v1_scrapes_url, params: { api_key: "123456789" }
    assert_response :success
  end

  test "creates and enqueues a scrape owned by the key's user" do
    assert_difference "Scrape.count", 1 do
      assert_enqueued_jobs 1, only: ScrapeJob do
        post media_vault_api_v1_scrapes_url, params: { url: INSTAGRAM_URL }, headers: auth_headers, as: :json
      end
    end
    assert_response :accepted

    scrape = Scrape.order(:created_at).last
    assert_equal users(:user), scrape.user
    assert_equal "api", scrape.initiated_from

    body = response.parsed_body
    assert_equal scrape.id, body["id"]
    assert_equal "pending", body["status"]
    assert_equal "instagram", body["platform"]
    assert_nil body["result"]
  end

  test "rejects an unsupported url" do
    assert_no_difference "Scrape.count" do
      post media_vault_api_v1_scrapes_url, params: { url: "https://example.com/post/1" }, headers: auth_headers, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "rejects a request without url" do
    post media_vault_api_v1_scrapes_url, params: {}, headers: auth_headers, as: :json
    assert_response :bad_request
  end

  test "shows a scrape of the key's user" do
    scrape = Scrape.create!({ url: INSTAGRAM_URL, scrape_type: :instagram, user: users(:user) })

    get media_vault_api_v1_scrape_url(scrape), headers: auth_headers
    assert_response :success
    assert_equal scrape.id, response.parsed_body["id"]
    assert_equal "pending", response.parsed_body["status"]
  end

  test "does not show another user's scrape" do
    scrape = Scrape.create!({ url: INSTAGRAM_URL, scrape_type: :instagram, user: users(:media_vault_user) })

    get media_vault_api_v1_scrape_url(scrape), headers: auth_headers
    assert_response :not_found
  end

  test "shows the result of a completed scrape" do
    AwsS3Downloader.stub(:download_file_in_s3_received_from_hypatia, S3_MOCK_STUB) do
      scrape = Scrape.create!({ url: "https://www.instagram.com/p/CHdIkUVBz3C", scrape_type: :instagram, user: users(:user) })
      zorki_image_post = InstagramMediaSource.extract("https://www.instagram.com/p/CHdIkUVBz3C/", MediaSource::ScrapeType::Instagram, true, initiated_from: Scrape.initiated_froms[:site])["scrape_result"]
      scrape.fulfill(zorki_image_post)

      get media_vault_api_v1_scrape_url(scrape), headers: auth_headers
      assert_response :success

      body = response.parsed_body
      assert_equal "completed", body["status"]
      result = body["result"]
      assert_equal scrape.reload.archive_item.id, result["id"]
      assert_equal "instagram", result["platform"]
      assert result["public_link"].present?
      assert result["author"].key?("username")
      assert result["media"].all? { |media| media["url"].present? && ["image", "video"].include?(media["type"]) }
    end
  end

  test "lists the key's user scrapes, filtered by status" do
    pending_scrape = Scrape.create!({ url: INSTAGRAM_URL, scrape_type: :instagram, user: users(:user) })
    errored_scrape = Scrape.create!({ url: INSTAGRAM_URL, scrape_type: :instagram, user: users(:user), error: true })
    other_scrape = Scrape.create!({ url: INSTAGRAM_URL, scrape_type: :instagram, user: users(:media_vault_user) })

    get media_vault_api_v1_scrapes_url, headers: auth_headers
    assert_response :success
    ids = response.parsed_body["scrapes"].map { |scrape| scrape["id"] }
    assert_includes ids, pending_scrape.id
    assert_includes ids, errored_scrape.id
    assert_not_includes ids, other_scrape.id
    assert_equal 1, response.parsed_body["pagination"]["page"]

    get media_vault_api_v1_scrapes_url, params: { status: "error" }, headers: auth_headers
    ids = response.parsed_body["scrapes"].map { |scrape| scrape["id"] }
    assert_equal [errored_scrape.id], ids
  end

  test "rejects an unknown status filter" do
    get media_vault_api_v1_scrapes_url, params: { status: "bogus" }, headers: auth_headers
    assert_response :bad_request
  end
end
