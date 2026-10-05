require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "non-admins cannot access the users admin" do
    sign_in users(:user)

    get admin_users_path
    assert_redirected_to "/"

    assert_no_difference "User.count" do
      post admin_users_path, params: { user: { name: "New Person", email: "new.person@example.com" } }
    end
  end

  test "admin can view the new user form" do
    sign_in users(:admin)

    get new_admin_user_path
    assert_response :success
  end

  test "admin can create a user" do
    sign_in users(:admin)

    assert_difference "User.count", 1 do
      assert_emails 1 do
        post admin_users_path, params: { user: { name: "New Person", email: "new.person@example.com", media_vault_enabled: "0" } }
      end
    end

    user = User.find_by(email: "new.person@example.com")
    assert_redirected_to admin_user_path(user)
    assert_predicate user, :confirmed?
    assert_predicate user, :is_new_user?
    assert_predicate user, :is_fact_check_insights_user?
    assert_not user.is_media_vault_user?
  end

  test "admin can create a Media Vault user" do
    sign_in users(:admin)

    post admin_users_path, params: { user: { name: "Vault Person", email: "vault.person@example.com", media_vault_enabled: "1" } }

    user = User.find_by(email: "vault.person@example.com")
    assert_predicate user, :is_media_vault_user?
  end

  test "admin can create a user in an organization" do
    sign_in users(:admin)

    post admin_users_path, params: { user: { name: "Org Person", email: "org.person@example.com", organization_id: organizations(:newsroom).id } }

    assert_equal organizations(:newsroom), User.find_by(email: "org.person@example.com").organization
  end

  test "creating a user with an existing email re-renders the form" do
    sign_in users(:admin)

    assert_no_difference "User.count" do
      post admin_users_path, params: { user: { name: "Duplicate", email: users(:admin).email } }
    end
    assert_response :unprocessable_entity
  end
end
