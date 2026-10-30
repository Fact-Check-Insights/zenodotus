require "test_helper"

class ApiKeyTest < ActiveSupport::TestCase
  test "creating an api key returns the clear string of the key" do
    api_key = ApiKey.create(user: users(:user), description: "Test client")
    assert_not_nil api_key.api_key
    assert_not_nil api_key.hashed_api_key
  end

  test "retrieving an api key does not return the clear string of the key" do
    api_key = ApiKey.create(user: users(:user), description: "Test client")
    api_key = ApiKey.find(api_key.id)
    assert_nil api_key.api_key
    assert_not_nil api_key.hashed_api_key
  end

  test "deleting a user deletes all of its api keys" do
    user = users(:user)
    api_key = ApiKey.create(user: user, description: "Test client")
    assert_not_nil api_key
    user.destroy!
    assert_raise(ActiveRecord::RecordNotFound) do
      ApiKey.find(api_key.id)
    end
  end

  test "creating an api key stores the start of the key as its prefix" do
    api_key = ApiKey.create!(user: users(:user), description: "Test client")
    assert_equal api_key.api_key.first(ApiKey::KEY_PREFIX_LENGTH), api_key.key_prefix
  end

  test "an api key requires a description" do
    api_key = ApiKey.new(user: users(:user))
    assert_not api_key.valid?
    assert_includes api_key.errors[:description], "can't be blank"
  end

  test "api keys are active by default" do
    api_key = ApiKey.create!(user: users(:user), description: "Test client")
    assert api_key.active
  end

  test "the active scope excludes inactive keys" do
    assert_includes ApiKey.active, api_keys(:one)
    assert_not_includes ApiKey.active, api_keys(:inactive)
  end
end
