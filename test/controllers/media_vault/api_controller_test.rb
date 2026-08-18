require "test_helper"

class MediaVault::ArchiveControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include Minitest::Hooks
  include TransactionalBeforeAll
end
