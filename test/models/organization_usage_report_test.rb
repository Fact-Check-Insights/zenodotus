require "test_helper"

class OrganizationUsageReportTest < ActiveSupport::TestCase
  def setup
    @organization = organizations(:newsroom)
    @member = users(:user)
    @other_member = users(:fact_check_insights_user)
    @outsider = users(:media_vault_user)

    @member.update!(organization: @organization)
    @other_member.update!(organization: @organization)
  end

  def scrape_for(user, at:, error: false)
    Scrape.insert!({ url: "https://twitter.com/jack/status/20", scrape_type: "twitter", user_id: user.id, error: error, created_at: at, updated_at: at })
  end

  test "counts usage by month and by user within the date range" do
    scrape_for(@member, at: Time.utc(2026, 1, 15))
    scrape_for(@member, at: Time.utc(2026, 1, 20), error: true)
    scrape_for(@member, at: Time.utc(2026, 3, 1))
    scrape_for(@other_member, at: Time.utc(2026, 3, 31, 23, 0))
    scrape_for(@outsider, at: Time.utc(2026, 1, 15)) # Not in the organization
    scrape_for(@member, at: Time.utc(2025, 12, 31)) # Before the range
    scrape_for(@member, at: Time.utc(2026, 4, 1)) # After the range
    TextSearch.create!(user: @other_member, query: "test", created_at: Time.utc(2026, 2, 10))
    CorpusDownload.create!(user: @member, download_type: :json, created_at: Time.utc(2026, 2, 11))

    report = OrganizationUsageReport.new(@organization, from: Date.new(2026, 1, 1), to: Date.new(2026, 3, 31))

    assert_equal [Date.new(2026, 1, 1), Date.new(2026, 2, 1), Date.new(2026, 3, 1)], report.months

    totals = report.totals
    assert_equal 4, totals[:scrape_requests]
    assert_equal 1, totals[:failed_scrapes]
    assert_equal 1, totals[:text_searches]
    assert_equal 1, totals[:corpus_downloads]
    assert_equal 0, totals[:archived_items]

    by_month = report.by_month
    assert_equal 2, by_month[Date.new(2026, 1, 1)][:scrape_requests]
    assert_equal 0, by_month[Date.new(2026, 2, 1)][:scrape_requests]
    assert_equal 1, by_month[Date.new(2026, 2, 1)][:text_searches]
    assert_equal 2, by_month[Date.new(2026, 3, 1)][:scrape_requests]

    by_user = report.by_user
    assert_equal [@member, @other_member].sort_by(&:name), by_user.keys
    assert_equal 3, by_user[@member][:scrape_requests]
    assert_equal 1, by_user[@other_member][:scrape_requests]
    assert_equal 1, by_user[@other_member][:text_searches]

    assert_equal 1, report.by_user_and_month[@other_member][Date.new(2026, 3, 1)][:scrape_requests]
  end

  test "an organization without users has no usage" do
    report = OrganizationUsageReport.new(organizations(:empty), from: Date.new(2026, 1, 1), to: Date.new(2026, 1, 31))

    assert_empty report.by_user
    assert report.totals.values.all?(&:zero?)
  end

  test "swaps the dates when they are reversed" do
    report = OrganizationUsageReport.new(@organization, from: Date.new(2026, 3, 31), to: Date.new(2026, 1, 1))

    assert_equal Date.new(2026, 1, 1), report.from
    assert_equal Date.new(2026, 3, 31), report.to
  end
end
