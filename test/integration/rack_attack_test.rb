require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  setup do
    # Clear rack-attack cache between tests
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
  end

  test "throttles excessive login attempts" do
    11.times do
      post user_session_path, params: { user: { email: "test@example.com", password: "wrongpassword!" } }
    end

    assert_equal 429, response.status
  end

  test "allows normal login attempts within limit" do
    5.times do
      post user_session_path, params: { user: { email: "test@example.com", password: "wrongpassword!" } }
    end

    assert_not_equal 429, response.status
  end
end
