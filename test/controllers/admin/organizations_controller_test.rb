require "test_helper"

class Admin::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "non-admins cannot access organizations" do
    sign_in users(:user)

    get admin_organization_path(organizations(:newsroom))
    assert_redirected_to "/"
  end

  test "admin can list, create and update organizations" do
    sign_in users(:admin)

    get admin_organizations_path
    assert_response :success

    assert_difference "Organization.count", 1 do
      post admin_organizations_path, params: { organization: { name: "New Newsroom" } }
    end
    organization = Organization.find_by(name: "New Newsroom")
    assert_redirected_to admin_organization_path(organization)

    patch admin_organization_path(organization), params: { organization: { name: "Renamed Newsroom" } }
    assert_equal "Renamed Newsroom", organization.reload.name
  end

  test "creating an organization with a duplicate name re-renders the form" do
    sign_in users(:admin)

    assert_no_difference "Organization.count" do
      post admin_organizations_path, params: { organization: { name: organizations(:newsroom).name } }
    end
    assert_response :unprocessable_entity
  end

  test "admin can view usage for a date range and download it as CSV" do
    sign_in users(:admin)
    users(:user).update!(organization: organizations(:newsroom))

    get admin_organization_path(organizations(:newsroom), from: "2026-01-01", to: "2026-03-31")
    assert_response :success

    get admin_organization_path(organizations(:newsroom), format: :csv, from: "2026-01-01", to: "2026-03-31")
    assert_response :success
    rows = CSV.parse(response.body)
    assert_equal "User", rows.first.first
    assert_equal 1 + 3, rows.size # Header, plus one row per month for the single user
  end

  test "invalid dates fall back to the defaults" do
    sign_in users(:admin)

    get admin_organization_path(organizations(:newsroom), from: "not-a-date")
    assert_response :success
  end

  test "deleting an organization keeps its users" do
    sign_in users(:admin)
    users(:user).update!(organization: organizations(:newsroom))

    delete admin_organization_path(organizations(:newsroom))

    assert_redirected_to admin_organizations_path
    assert User.exists?(users(:user).id)
    assert_nil users(:user).reload.organization
  end

  test "admin can assign a user to an organization" do
    sign_in users(:admin)

    patch admin_user_path(users(:user)), params: { user: { organization_id: organizations(:newsroom).id } }
    assert_equal organizations(:newsroom), users(:user).reload.organization

    patch admin_user_path(users(:user)), params: { user: { organization_id: "" } }
    assert_nil users(:user).reload.organization
  end
end
