# typed: ignore

# Management of the API keys used by external clients of the scrapes API
class Admin::ApiKeysController < AdminController
  API_KEYS_PER_PAGE = 25

  before_action :set_api_key, only: [:edit, :update, :destroy]
  before_action :set_users, only: [:new, :create]

  def index
    @pagy_items, @api_keys = pagy(
      ApiKey.includes(:user).order(created_at: :desc),
      page_param: :p,
      items: API_KEYS_PER_PAGE
    )
  end

  def new
    @api_key = ApiKey.new(user: current_user)
  end

  def create
    @api_key = ApiKey.new(create_params)

    if @api_key.save
      # The clear key only exists right now, so it's rendered instead of redirecting
      response.headers["Cache-Control"] = "no-store"
      render :created, status: :created
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @api_key.update(update_params)
      redirect_to admin_api_keys_path, notice: t("api_keys.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @api_key.destroy
    redirect_to admin_api_keys_path, notice: t("api_keys.flash.deleted")
  end

private

  def set_api_key
    @api_key = ApiKey.find(params[:id])
  end

  # Only users who can access MediaVault can use the scrapes API
  def set_users
    @users = User.joins(:roles).where(roles: { name: ["admin", "media_vault_user"] }).distinct.order(:name)
  end

  def create_params
    params.require(:api_key).permit(:description, :active, :user_id)
  end

  # The owner can't be changed once the key has been handed out
  def update_params
    params.require(:api_key).permit(:description, :active)
  end
end
