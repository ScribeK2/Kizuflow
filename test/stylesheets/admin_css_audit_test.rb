require "test_helper"

# admin.css grew its own palette: literal oklch() fills beside hand-written
# [data-theme="dark"] overrides, which UIGUIDE forbids because the tokens in
# _global.css already swap per theme. The visible cost was the users bulk-action
# bar — ink-filled, so in dark mode a bright slab whose white-alpha buttons
# measured 1.04:1 against it. This keeps the file on tokens.
class AdminCssAuditTest < ActiveSupport::TestCase
  CSS = Rails.root.join("app/assets/stylesheets/admin.css").read.gsub(%r{/\*.*?\*/}m, "").freeze

  test "admin.css uses colour tokens, never literal colours" do
    literals = CSS.scan(/oklch\(|rgba?\(|hsla?\(|:[^;{}]*#\h{3,8}\b/)
    assert_empty literals, "use var(--color-*) tokens; found #{literals.uniq.join(', ')}"
  end

  # assert_not rather than assert_no_match: the latter prints the whole file.
  test "admin.css writes no theme overrides of its own" do
    assert_not CSS.include?("[data-theme"), "a [data-theme] block in admin.css is a second palette"
    assert_not CSS.include?("prefers-color-scheme"), "theme media queries belong in _global.css"
  end
end
