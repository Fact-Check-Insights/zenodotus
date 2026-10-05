require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "requires a unique name" do
    assert_not Organization.new(name: "").valid?
    assert_not Organization.new(name: organizations(:newsroom).name.upcase).valid?
    assert_predicate Organization.new(name: "Another Newsroom"), :valid?
  end

  test "deleting an organization keeps its users" do
    user = users(:user)
    user.update!(organization: organizations(:newsroom))

    organizations(:newsroom).destroy

    assert_nil user.reload.organization
  end
end
