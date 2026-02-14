require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "render_step_markdown renders basic markdown" do
    result = render_step_markdown("**bold** and *italic*")
    assert_includes result, "<strong>bold</strong>"
    assert_includes result, "<em>italic</em>"
  end

  test "render_step_markdown renders image tags from markdown" do
    result = render_step_markdown("![Screenshot](https://example.com/image.png)")
    assert_includes result, "<img"
    assert_includes result, 'src="https://example.com/image.png"'
    assert_includes result, 'alt="Screenshot"'
  end

  test "render_step_markdown adds step-image class to images" do
    result = render_step_markdown("![Test](https://example.com/test.jpg)")
    assert_includes result, "step-markdown-image"
  end

  test "render_step_markdown blocks javascript in image src" do
    result = render_step_markdown("![xss](javascript:alert(1))")
    assert_not_includes result, "javascript:"
  end

  test "render_step_markdown blocks data URIs in image src" do
    result = render_step_markdown("![data](data:text/html,<script>alert(1)</script>)")
    assert_not_includes result, "data:"
  end

  test "render_step_markdown allows only http and https image sources" do
    http_result = render_step_markdown("![ok](http://example.com/img.png)")
    assert_includes http_result, 'src="http://example.com/img.png"'

    https_result = render_step_markdown("![ok](https://example.com/img.png)")
    assert_includes https_result, 'src="https://example.com/img.png"'
  end

  test "render_step_markdown allows rails active storage paths" do
    result = render_step_markdown("![file](/rails/active_storage/blobs/redirect/abc123/photo.png)")
    assert_includes result, 'src="/rails/active_storage/blobs/redirect/abc123/photo.png"'
  end

  test "render_step_markdown returns empty string for blank text" do
    assert_equal "", render_step_markdown(nil)
    assert_equal "", render_step_markdown("")
  end
end
