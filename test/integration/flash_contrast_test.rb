require "test_helper"

# `.flash__body` hardcoded `color: oklch(1 0 0)` over the `--color-negative` and
# `--color-positive` fills. UIGUIDE forbids exactly that, because in dark mode
# those tokens are *light* fills (L 0.80) — they are sized for text, not for
# backgrounds. Measured with canvas-sampled sRGB on the real computed styles:
#
#     light / alert    6.44  pass       dark / alert   1.95  FAIL
#     light / notice   7.02  pass       dark / notice  1.80  FAIL
#
# Under 2:1 is below even the 3:1 large-text floor, so every error and success
# message in the application was effectively unreadable in dark mode. The
# `--color-on-*` tokens already existed and already swapped correctly; using them
# gives 10.32:1 and 11.18:1.
#
# This is a stylesheet assertion rather than a rendered-contrast one on purpose.
# Minitest cannot resolve OKLCH or run the cascade, and a test that computed
# contrast itself would be reimplementing the browser. What it *can* pin is the
# rule the browser needs: a semantic fill must take its text colour from the
# matching on-token, never from a literal.
class FlashContrastTest < ActiveSupport::TestCase
  FLASH_CSS = Rails.root.join("app/assets/stylesheets/flash.css")

  # variant => the fill token it uses, and therefore the on-token it must pair with
  VARIANTS = {
    "notice" => %w[--color-positive --color-on-positive],
    "alert" => %w[--color-negative --color-on-negative]
  }.freeze

  VARIANTS.each do |variant, (fill, on_token)|
    test "flash--#{variant} pairs #{fill} with #{on_token}" do
      block = rule_body(/\.flash--#{variant}\s+\.flash__body\s*\{([^}]*)\}/m)

      assert block, ".flash--#{variant} .flash__body has no rule in flash.css"
      assert_match(/background:\s*var\(#{fill}\)/, block,
                   "expected .flash--#{variant} to fill with #{fill}")
      assert_match(/color:\s*var\(#{on_token}\)/, block, <<~MESSAGE)
        .flash--#{variant} does not take its text colour from #{on_token}.

        #{fill} is sized for text, so in dark mode it is a light fill (L 0.80).
        White on it measures under 2:1. Rule as found:

        #{block.strip}
      MESSAGE
    end
  end

  test "no rule in flash.css hardcodes a literal white text colour" do
    offenders = stylesheet.scan(/([^{}]+)\{([^}]*)\}/m).filter_map do |selector, body|
      next unless body.match?(/color:\s*oklch\(\s*1\s+0\s+0\s*\)/)

      selector.strip
    end

    assert_empty offenders, <<~MESSAGE
      These rules hardcode white text:

        #{offenders.join("\n  ")}

      On a semantic fill that fails AA in dark mode, where the token is a light
      fill. Use var(--color-on-negative) / --color-on-positive / --color-on-warning,
      which are white in light mode and ink in dark.
    MESSAGE
  end

  test "the dark-mode overrides that restated the same background are gone" do
    # There used to be `[data-theme="dark"] .flash--notice .flash__body { background:
    # var(--color-positive) }` — the identical declaration, doing nothing, while
    # implying the variant needed a dark-mode branch. Tokens swap on their own.
    assert_no_match(/\[data-theme="dark"\]\s*\.flash--/, stylesheet, <<~MESSAGE)
      flash.css has a [data-theme="dark"] override for a flash variant.

      UIGUIDE: "Do not write separate dark mode CSS." If a token is right, it
      swaps by itself; if it is wrong, the fix is the token, not a branch.
    MESSAGE
  end

  private

  def rule_body(pattern)
    match = stylesheet.match(pattern)
    match && match[1]
  end

  # Comments stripped: this file explains the very tokens under test, and a
  # property named in prose must not satisfy an assertion.
  def stylesheet
    @stylesheet ||= begin
      assert_path_exists FLASH_CSS
      FLASH_CSS.read.gsub(%r{/\*.*?\*/}m, "")
    end
  end
end
