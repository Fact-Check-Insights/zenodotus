# typed: strict

class PrivacyPolicyAcceptanceController < ApplicationController
  extend T::Sig

  before_action :authenticate_user!
  skip_before_action :require_privacy_policy_acceptance

  sig { void }
  def show
    @page_metadata = { title: "Privacy Policy Update", description: "Privacy Policy Update" }
  end

  sig { void }
  def accept
    current_user.update!(privacy_policy_accepted_at: Time.current)

    respond_to do |format|
      format.html do
        redirect_to after_sign_in_path_for(current_user), notice: "Thank you for accepting the privacy policy."
      end
      format.json do
        render json: { success: true }, status: :ok
      end
    end
  end
end
