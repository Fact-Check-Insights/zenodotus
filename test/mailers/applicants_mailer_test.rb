require "test_helper"

class ApplicantsMailerTest < ActionMailer::TestCase
  test "duplicate_registration_email sends to the correct address with expected content" do
    site = SiteDefinitions::FACT_CHECK_INSIGHTS
    email_address = "user@example.com"

    email = ApplicantsMailer.with(
      site: site,
      email: email_address,
    ).duplicate_registration_email

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [email_address], email.to
    assert_equal "Your #{site[:title]} account", email.subject
    assert_includes email.text_part.body.to_s, "You already have an account"
    assert_includes email.html_part.body.to_s, "You already have an account"
  end
end
