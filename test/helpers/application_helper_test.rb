require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "render_rich_text wraps content in prose div without html_safe on plain strings" do
    result = render_rich_text("Hello <script>alert('xss')</script>")
    assert_no_match(/<script>/, result)
    assert_match(/Hello/, result)
  end

  test "render_rich_text returns nil for blank content" do
    assert_nil render_rich_text(nil)
    assert_nil render_rich_text("")
  end
end
