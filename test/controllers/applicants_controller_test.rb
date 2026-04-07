require "test_helper"

class ApplicantsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "can access the apply page while logged out" do
    get new_applicant_url
    assert_response :success
  end

  test "cannot access the apply page while logged in" do
    user = users(:user)

    sign_in user

    get new_applicant_url
    assert_response :redirect
  end

  test "creates an applicant" do
    post applicants_url(applicant: {
      name: "Jane Doe",
      email: "applicant@example.com",
      use_case: "Journalism?",
      accepted_terms: "1",
      commercial_use: "false",
    })

    assert Applicant.find_by(email: "applicant@example.com")
    assert_redirected_to applicant_confirmation_sent_url
  end

  test "redirects to confirmation sent page after creation" do
    post applicants_url(applicant: {
      name: "Jane Doe",
      email: "applicant@example.com",
      use_case: "Journalism?",
      accepted_terms: "1",
      commercial_use: "false",
    })

    assert_redirected_to applicant_confirmation_sent_url
  end

  test "returns a bad request if validations fails during creation" do
    post applicants_url(applicant: {
      name: "Jane Doe",
    })

    assert_response :unprocessable_entity
  end

  test "should redirect to confirmation page when applying with existing user email" do
    user = users(:user)

    post applicants_url(applicant: {
      name: "Jane Doe",
      email: user.email,
      use_case: "Journalism?",
      accepted_terms: "1",
      commercial_use: "false",
    })

    assert_redirected_to applicant_confirmation_sent_url

    email = ActionMailer::Base.deliveries.last
    assert_equal [user.email], email.to
    assert_includes email.subject, "account"
  end

  test "should redirect to confirmation page when applying with existing user email in different case" do
    user = users(:user)

    post applicants_url(applicant: {
      name: "Jane Doe",
      email: user.email.upcase,
      use_case: "Journalism?",
      accepted_terms: "1",
      commercial_use: "false",
    })

    assert_redirected_to applicant_confirmation_sent_url

    email = ActionMailer::Base.deliveries.last
    assert_equal [user.email.downcase], email.to
    assert_includes email.subject, "account"
  end

  test "should not create an applicant when applying with existing user email" do
    user = users(:user)

    assert_no_difference "Applicant.count" do
      post applicants_url(applicant: {
        name: "Jane Doe",
        email: user.email,
        use_case: "Journalism?",
        accepted_terms: "1",
        commercial_use: "false",
      })
    end
  end

  test "should lowercase email address during creation" do
    email_upcase = "APPLICANT@EXAMPLE.COM"
    email_downcase = email_upcase.downcase

    post applicants_url(applicant: {
      name: "Jane Doe",
      email: email_upcase,
      use_case: "Journalism?",
      accepted_terms: "1",
      commercial_use: "false",
    })

    assert_nil Applicant.find_by(email: email_upcase)

    applicant = Applicant.find_by(email: email_downcase)

    assert_equal email_downcase, applicant.email
  end

  test "should default the site source to Insights" do
    post applicants_url(applicant: {
      name: "Jane Doe",
      email: "applicant-insights@example.com",
      use_case: "Journalism?",
      accepted_terms: "1",
      commercial_use: "false",
    })
    applicant = Applicant.find_by(email: "applicant-insights@example.com")

    assert_equal SiteDefinitions::FACT_CHECK_INSIGHTS[:shortname], applicant[:source_site]
  end

  test "can record that an applicant came from the Vault application page" do
    host! Figaro.env.MEDIA_VAULT_HOST

    post applicants_url(applicant: {
      name: "Jane Doe",
      email: "applicant-vault@example.com",
      use_case: "Journalism?",
      accepted_terms: "1",
      commercial_use: "false",
    })
    applicant = Applicant.find_by(email: "applicant-vault@example.com")

    assert_equal SiteDefinitions::MEDIA_VAULT[:shortname], applicant[:source_site]
  end

  test "creates an applicant with all new fields" do
    post applicants_url(applicant: {
      name: "Jane Doe",
      email: "newfields@example.com",
      use_case: "Journalism?",
      accepted_terms: "1",
      organization_type: "University",
      primary_role: "Researcher",
      commercial_use: "false",
    })

    applicant = Applicant.find_by(email: "newfields@example.com")
    assert applicant
    assert_equal "University", applicant.organization_type
    assert_equal "Researcher", applicant.primary_role
    assert_equal false, applicant.commercial_use
    assert_redirected_to applicant_confirmation_sent_url
  end

  test "creates an applicant with Other fields" do
    post applicants_url(applicant: {
      name: "Jane Doe",
      email: "otherfields@example.com",
      use_case: "Journalism?",
      accepted_terms: "1",
      organization_type: "Other",
      organization_type_other: "Custom org",
      primary_role: "Other",
      primary_role_other: "Custom role",
      commercial_use: "true",
    })

    applicant = Applicant.find_by(email: "otherfields@example.com")
    assert applicant
    assert_equal "Other", applicant.organization_type
    assert_equal "Custom org", applicant.organization_type_other
    assert_equal "Other", applicant.primary_role
    assert_equal "Custom role", applicant.primary_role_other
    assert_equal true, applicant.commercial_use
    assert_redirected_to applicant_confirmation_sent_url
  end

  test "can confirm an applicant" do
    applicant = applicants(:new)

    assert_not applicant.confirmed?

    get applicant_confirm_url(email: applicant[:email], token: applicant[:confirmation_token])

    applicant.reload
    assert_predicate applicant, :confirmed?
  end

  test "can reconfirm an applicant" do
    applicant = applicants(:confirmed)

    assert_predicate applicant, :confirmed?

    get applicant_confirm_url(email: applicant[:email], token: applicant[:confirmation_token])

    applicant.reload
    assert_redirected_to("http://www.example.com/apply/confirm/done")
  end
end
