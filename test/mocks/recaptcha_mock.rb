module RecaptchaMock
  # The token tests should submit to get a passing assessment. Any other token is
  # assessed as invalid, so tests can exercise the rejection path too.
  VALID_TOKEN = "test-recaptcha-token".freeze

  TokenProperties = Struct.new(:valid, :invalid_reason, :action, keyword_init: true)
  RiskAnalysis = Struct.new(:score, keyword_init: true)
  Assessment = Struct.new(:token_properties, :risk_analysis, keyword_init: true)

  # Stands in for the reCAPTCHA Enterprise client so that the controller's own
  # verification logic still runs, without any call to Google.
  class Client
    def create_assessment(parent:, assessment:)
      token = assessment[:event][:token]
      valid = token == VALID_TOKEN

      Assessment.new(
        token_properties: TokenProperties.new(
          valid: valid,
          invalid_reason: valid ? nil : :INVALID,
          action: assessment[:event][:expected_action] || "apply"
        ),
        risk_analysis: RiskAnalysis.new(score: valid ? 0.9 : 0.0)
      )
    end
  end

  # Replaces the real service factory for the duration of the test run.
  def self.install!
    ::Google::Cloud::RecaptchaEnterprise.define_singleton_method(:recaptcha_enterprise_service) do |*_args, **_kwargs|
      Client.new
    end
  end
end
