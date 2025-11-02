require "test_helper"

class UserTest < ActiveSupport::TestCase
  # Load fixtures only for model tests that need them
  fixtures :users

  test "should create valid user" do
    user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert user.valid?
  end

  test "should not create user without email" do
    user = User.new(password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should not create user without password" do
    user = User.new(email: "test@example.com")
    assert_not user.valid?
  end

  test "should have many workflows" do
    user = users(:one)
    assert_respond_to user, :workflows
  end

  test "should destroy workflows when user is destroyed" do
    user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    workflow = Workflow.create!(title: "Test", user: user)
    
    assert_difference("Workflow.count", -1) do
      user.destroy
    end
  end
end

