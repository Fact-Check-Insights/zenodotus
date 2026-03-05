class ApplicantsMailer < ApplicationMailer
  def confirmation_email
    @site = params[:site]
    @applicant = params[:applicant]

    mail({
      from: email_address_with_name("no-reply@#{Figaro.env.MAIL_DOMAIN}", @site[:title]),
      to: @applicant[:email],
      subject: "Please confirm your email address for #{@site[:title]}"
    })
  end

  def duplicate_registration_email
    @site = params[:site]
    @email = params[:email]

    mail({
      from: email_address_with_name("no-reply@#{Figaro.env.MAIL_DOMAIN}", @site[:title]),
      to: @email,
      subject: "Your #{@site[:title]} account"
    })
  end
end
