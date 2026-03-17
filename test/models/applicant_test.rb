require "test_helper"
require "action_mailer/test_helper"

class ApplicantTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def setup
    @applicant = Applicant.new
  end

  test "requires all required fields to be set" do
    assert_not @applicant.valid?

    @applicant.name = "John Doe"
    assert_not @applicant.valid?

    @applicant.email = "john@example.com"
    assert_not @applicant.valid?

    @applicant.use_case = "Journalism and fact-checking."
    assert_not @applicant.valid?

    @applicant.commercial_use = false
    assert_not @applicant.valid?

    @applicant.accepted_terms = true
    assert_predicate @applicant, :valid?

    @applicant.accepted_terms = false
    assert_not @applicant.valid?
  end

  test "should lowercase email address during creation" do
    applicant = Applicant.create!({
      name: "Jane Doe",
      email: "JANE@EXAMPLE.COM",
      use_case: "Use case",
      accepted_terms_at: Time.now,
      accepted_terms_version: TermsOfService::CURRENT_VERSION,
      confirmation_token: Devise.friendly_token,
      commercial_use: false,
    })

    assert_equal applicant.email.downcase, applicant.email
  end

  test "cannot create an applicant without accepting terms" do
    assert_raises ActiveRecord::RecordInvalid do
      Applicant.create!({
        name: "John Doe",
        email: "john@example.com"
      })
    end
  end

  test "can send an applicant confirmation email" do
    a = Applicant.create!({
      name: "Jane Doe",
      email: "JANE@EXAMPLE.COM",
      use_case: "Use case",
      accepted_terms_at: Time.now,
      accepted_terms_version: TermsOfService::CURRENT_VERSION,
      confirmation_token: Devise.friendly_token,
      commercial_use: false,
    })

    assert_emails 1 do
      a.send_confirmation_email(SiteDefinitions::FACT_CHECK_INSIGHTS)
    end
  end

  # This test ensures that if the model has its terms-acceptance database attributes populated
  # properly, that the model itself sets the `accepted_terms` attribute accordingly during init.
  test "can convert terms-acceptance attributes from database" do
    assert applicants(:new).accepted_terms
  end

  # This test ensures that if the user's accepted terms don't match the current version, then they
  # have not "accepted the terms".
  test "must have accepted most recent terms" do
    assert_not applicants(:expired_terms).accepted_terms
  end

  # If the user has accepted terms, then they are initially valid.
  # If they attempt to unaccept, their model should not be valid.
  test "cannot un-accept terms" do
    new_applicant = applicants(:new)
    assert_predicate new_applicant, :valid?

    assert_raises ActiveRecord::RecordInvalid do
      new_applicant.update!({
        accepted_terms: false
      })
    end
  end

  test "can edit applicant without triggering acceptance errors" do
    new_applicant = applicants(:new)

    assert new_applicant.update({
      name: "Janes Doe"
    })
  end

  test "can determine confirmation status correctly" do
    new_applicant = applicants(:new)

    assert_not new_applicant.confirmed?

    new_applicant.confirm

    assert_predicate new_applicant, :confirmed?
  end

  test "does not reconfirm if already confirmed" do
    new_applicant = applicants(:new)

    assert new_applicant.confirm

    # Cache this timestamp so we can compare against it later
    confirmed_at = new_applicant.confirmed_at

    new_applicant.confirm

    # The timestamps should remain equal
    assert_equal confirmed_at, new_applicant.confirmed_at
  end

  test "can only review a confirmed applicant" do
    new_applicant = applicants(:new)

    assert_raises Applicant::UnconfirmedError do
      new_applicant.approve
    end

    new_applicant.confirm
    new_applicant.approve

    assert_predicate new_applicant, :approved?
  end

  test "can approve an applicant only once" do
    confirmed_applicant = applicants(:confirmed)

    confirmed_applicant.approve

    assert_predicate confirmed_applicant, :approved?
    assert_raises Applicant::StatusChangeError do
      confirmed_applicant.approve
    end
  end

  test "can reject an applicant only once" do
    confirmed_applicant = applicants(:confirmed)

    confirmed_applicant.reject

    assert_predicate confirmed_applicant, :rejected?
    assert_raises Applicant::StatusChangeError do
      confirmed_applicant.reject
    end
  end

  test "can determine review status of applicant" do
    confirmed_applicant = applicants(:confirmed)

    assert_predicate confirmed_applicant, :unreviewed?
    assert_not confirmed_applicant.reviewed?

    confirmed_applicant.approve

    assert_not confirmed_applicant.unreviewed?
    assert_predicate confirmed_applicant, :reviewed?
  end

  test "can add notes during approval" do
    confirmed_applicant = applicants(:confirmed)

    review_note = "Friend of mine"

    confirmed_applicant.approve(
      review_note: review_note,
      review_note_internal: review_note
    )

    assert_equal review_note, confirmed_applicant.review_note
    assert_equal review_note, confirmed_applicant.review_note_internal
  end

  test "can add notes during rejection" do
    confirmed_applicant = applicants(:confirmed)

    review_note = "Friend of mine"

    confirmed_applicant.reject(
      review_note: review_note,
      review_note_internal: review_note
    )

    assert_equal review_note, confirmed_applicant.review_note
    assert_equal review_note, confirmed_applicant.review_note_internal
  end

  test "can associate a reviewer" do
    admin = users(:admin)
    confirmed_applicant = applicants(:confirmed)

    confirmed_applicant.approve(
      reviewer: admin
    )
    confirmed_applicant.reload

    assert_equal admin, confirmed_applicant.reviewer
  end

  test "validates organization_type inclusion" do
    applicant = Applicant.new(
      name: "John Doe",
      email: "john@example.com",
      use_case: "Research",
      accepted_terms: true,
      commercial_use: false,
      organization_type: "Invalid Type"
    )
    assert_not applicant.valid?
    assert applicant.errors[:organization_type].any?

    applicant.organization_type = "University"
    assert_predicate applicant, :valid?
  end

  test "validates primary_role inclusion on create" do
    applicant = Applicant.new(
      name: "John Doe",
      email: "john@example.com",
      use_case: "Research",
      accepted_terms: true,
      commercial_use: false,
      primary_role: "Invalid Role"
    )
    assert_not applicant.valid?
    assert applicant.errors[:primary_role].any?

    applicant.primary_role = "Researcher"
    assert_predicate applicant, :valid?
  end

  test "requires organization_type_other when organization_type is Other" do
    applicant = Applicant.new(
      name: "John Doe",
      email: "john@example.com",
      use_case: "Research",
      accepted_terms: true,
      commercial_use: false,
      organization_type: "Other"
    )
    assert_not applicant.valid?
    assert applicant.errors[:organization_type_other].any?

    applicant.organization_type_other = "My custom org"
    assert_predicate applicant, :valid?
  end

  test "requires primary_role_other when primary_role is Other" do
    applicant = Applicant.new(
      name: "John Doe",
      email: "john@example.com",
      use_case: "Research",
      accepted_terms: true,
      commercial_use: false,
      primary_role: "Other"
    )
    assert_not applicant.valid?
    assert applicant.errors[:primary_role_other].any?

    applicant.primary_role_other = "My custom role"
    assert_predicate applicant, :valid?
  end

  test "requires commercial_use to be set" do
    applicant = Applicant.new(
      name: "John Doe",
      email: "john@example.com",
      use_case: "Research",
      accepted_terms: true
    )
    assert_not applicant.valid?
    assert applicant.errors[:commercial_use].any?

    applicant.commercial_use = false
    assert_predicate applicant, :valid?

    applicant.commercial_use = true
    assert_predicate applicant, :valid?
  end

  test "sends email to admins when confirmed" do
    ActionMailer::Base.deliveries.clear # clear all emails

    new_applicant = applicants(:new)

    assert_emails 1 do
      assert new_applicant.confirm
    end
  end
end
