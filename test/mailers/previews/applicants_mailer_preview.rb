# Preview all emails at http://localhost:3000/rails/mailers/applicants_mailer
class ApplicantsMailerPreview < ActionMailer::Preview
  def confirmation_email
    ApplicantsMailer.with(
      applicant: {
        email: "applicant@example.com",
        confirmation_token: "asdf1234",
      },
      site: SiteDefinitions::FACT_CHECK_INSIGHTS,
    ).confirmation_email
  end

  def duplicate_registration_email
    ApplicantsMailer.with(
      email: "user@example.com",
      site: SiteDefinitions::FACT_CHECK_INSIGHTS,
    ).duplicate_registration_email
  end
end
