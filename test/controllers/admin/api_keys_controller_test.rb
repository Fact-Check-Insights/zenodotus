# typed: ignore

require "test_helper"

class Admin::ApiKeysControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "redirects without authentication" do
    get admin_api_keys_url
    assert_redirected_to "/"
  end

  test "non-admins cannot access api keys" do
    sign_in users(:user)

    get admin_api_keys_url
    assert_redirected_to "/"

    assert_no_difference "ApiKey.count" do
      post admin_api_keys_url, params: { api_key: { description: "Sneaky", user_id: users(:user).id } }
    end
  end

  test "admin can list api keys" do
    sign_in users(:admin)

    get admin_api_keys_url
    assert_response :success
    assert_select "tr#api_key_#{api_keys(:one).id}", text: /Test client/
    assert_select "tr#api_key_#{api_keys(:inactive).id}", text: /Revoked client/
  end

  test "admin dashboard links to api keys" do
    sign_in users(:admin)

    get admin_root_url
    assert_select "a[href=?]", admin_api_keys_path
  end

  test "admin can create an api key and sees the clear key only once" do
    sign_in users(:admin)

    get new_admin_api_key_url
    assert_response :success

    assert_difference "ApiKey.count", 1 do
      post admin_api_keys_url, params: { api_key: { description: "Newsroom client", user_id: users(:user).id, active: "1" } }
    end
    assert_response :created

    api_key = ApiKey.order(:created_at).last
    assert_equal "Newsroom client", api_key.description
    assert_equal users(:user), api_key.user
    assert api_key.active

    clear_key = css_select("#api-key-value").first["value"]
    assert_equal ZenoEncryption.hash_string(clear_key), api_key.hashed_api_key

    get admin_api_keys_url
    assert_no_match clear_key, response.body
  end

  test "creating an api key without a description re-renders the form" do
    sign_in users(:admin)

    assert_no_difference "ApiKey.count" do
      post admin_api_keys_url, params: { api_key: { description: "", user_id: users(:user).id } }
    end
    assert_response :unprocessable_entity
  end

  test "admin can edit and deactivate an api key but not change its owner" do
    sign_in users(:admin)
    api_key = api_keys(:one)

    get edit_admin_api_key_url(api_key)
    assert_response :success

    patch admin_api_key_url(api_key), params: { api_key: { description: "Renamed client", active: "0", user_id: users(:admin).id } }
    assert_redirected_to admin_api_keys_path

    api_key.reload
    assert_equal "Renamed client", api_key.description
    assert_not api_key.active
    assert_equal users(:user), api_key.user
  end

  test "admin can delete an api key" do
    sign_in users(:admin)

    assert_difference "ApiKey.count", -1 do
      delete admin_api_key_url(api_keys(:one))
    end
    assert_redirected_to admin_api_keys_path
  end
end
