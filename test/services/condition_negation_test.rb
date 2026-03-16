require "test_helper"

class ConditionNegationTest < ActiveSupport::TestCase
  include ConditionNegation

  test "negates equality operator to inequality" do
    assert_equal "answer != 'yes'", negate_condition("answer == 'yes'")
  end

  test "negates inequality operator to equality" do
    assert_equal "answer == 'no'", negate_condition("answer != 'no'")
  end

  test "wraps other conditions with NOT" do
    assert_equal "!(score > 10)", negate_condition("score > 10")
  end

  test "returns nil for blank input" do
    assert_nil negate_condition(nil)
    assert_nil negate_condition("")
  end

  test "handles conditions with multiple equality operators" do
    assert_equal "a != 1 && b != 2", negate_condition("a == 1 && b == 2")
  end
end
