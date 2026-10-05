class Admin::UsersController < AdminController
  USERS_PER_PAGE = 50

  def index
    @query = params[:query]

    if @query.present?
      @users = User.where("email LIKE ? OR name LIKE ?", "%#{@query}%", "%#{@query}%")
    else
      @users = User.all
    end

    @pagy_items, @users = pagy_array(
      @users,
      page_param: :p,
      items: USERS_PER_PAGE
    )
  end

  def show
    @user = User.find(params[:id])
  end

  def new
    @user = User.new
  end

  def create
    @user = User.create_by_admin(
      name: user_params[:name].to_s.strip,
      email: user_params[:email].to_s.strip,
      media_vault: user_params[:media_vault_enabled] == "1",
    )
    @user.send_setup_instructions

    redirect_to admin_user_path(@user), notice: "User created. Setup instructions have been sent to #{@user.email}."
  rescue ActiveRecord::RecordInvalid => e
    @user = e.record
    @media_vault_enabled = user_params[:media_vault_enabled] == "1"
    render :new, status: :unprocessable_entity
  end

  def reset_mfa
    @user = User.find(params[:user_id])
    @user.reset_mfa!
    redirect_to admin_user_path(@user), notice: "MFA reset for user."
  end

private

  def user_params
    params.require(:user).permit(:name, :email, :media_vault_enabled)
  end
end
