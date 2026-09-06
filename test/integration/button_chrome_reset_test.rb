require "test_helper"

# A `<button>` with no background or border of its own renders as the browser's
# own chrome — grey ButtonFace fill, outset bevel, square corners — because
# `reset.css` historically neutralised only `font` and `color` on buttons.
#
# That failure is close to invisible in review. The markup looks fine, and in
# light mode `rgb(239, 239, 239)` hides against a pale surface; only in dark
# mode, where the UA value stays light while the tokens go dark, does it read
# obviously wrong. It shipped three times before anyone measured it:
# `.file-dropzone`, `.dark-mode-toggle`, then `.scenario-exec-toggle` and
# `.wf-status-tabs__tab` together.
#
# Two guards, both narrow on purpose:
#
#   1. The reset still neutralises button chrome. This is the rule the whole
#      class of bug now depends on, so deleting or weakening it must fail here
#      rather than in a screenshot six months from now.
#
#   2. The two components that were caught relying on the UA declare their own
#      background. A component should not depend on the reset for its own
#      appearance — the reset is a floor, not a substitute for saying what the
#      element looks like.
#
# What this test deliberately does NOT do is walk every class in the app looking
# for missing declarations. `player_layout_stylesheet_coverage_test.rb` explains
# why that shape of assertion becomes noise: a class styled nowhere at all is
# ordinary, since Stimulus targets and JS state hooks carry no rules.
class ButtonChromeResetTest < ActiveSupport::TestCase
  STYLESHEET_DIR = Rails.root.join("app/assets/stylesheets")

  test "the reset neutralises the browser's own button chrome" do
    # The union of every reset rule that applies to a bare `button`, because the
    # cascade is what the browser sees. Which rule carries which declaration does
    # not matter and should not be something this test has an opinion about.
    declarations = rules_matching_bare_button("reset.css")

    assert_not_empty declarations, <<~MESSAGE
      reset.css no longer has any rule selecting a bare `button`.

      Without one, any button whose class forgets a background or a border falls
      back to the browser's chrome. See the comment at the top of this test.
    MESSAGE

    combined = declarations.join("\n")

    %w[background border padding].each do |property|
      assert_match(/(^|\s|;)#{property}\s*:/, combined, <<~MESSAGE)
        No reset.css rule for `button` sets `#{property}`.

        All three are needed: `background` and `border` remove the UA's fill and
        bevel, `padding` removes the UA's inset so a component's own padding is
        the only padding. Declarations found across #{declarations.size} rule(s):

        #{combined.strip}
      MESSAGE
    end
  end

  # Both were live instances. `.scenario-exec-toggle` rendered a 2px outset black
  # bevel on every run's results page; `.wf-status-tabs__tab` set a background
  # only in its `.is-active` variant, so as an <a> (the workflows status strip)
  # the inactive state fell through to transparent and looked right, while as a
  # <button> (the analytics filters) it took ButtonFace — which in dark mode made
  # the *unselected* segments read as the selected one.
  {
    "scenarios.css" => ".scenario-exec-toggle",
    "tabs.css" => ".wf-status-tabs__tab"
  }.each do |sheet, selector|
    test "#{selector} declares its own background rather than inheriting the reset's" do
      block = rule_block(sheet, /(^|\n)\s*#{Regexp.escape(selector)}\s*\{([^}]*)\}/m)

      assert block, "#{selector} has no base rule in #{sheet}"
      assert_match(/(^|\s|;)background\s*:/, block, <<~MESSAGE)
        #{selector} does not set its own `background`.

        The reset now covers it, so this will not render as browser chrome — but
        a component that leaves its resting appearance to the reset is one rule
        away from the bug again, and the next reader cannot see what state it is
        supposed to be in. Declare it.

        Rule as found:
        #{block.strip}
      MESSAGE
    end
  end

  private

  # Declaration bodies of every rule in `sheet` whose selector list contains a
  # standalone `button` — not `button.something`, not `.x button`, which target
  # narrower sets and would let a partial reset pass.
  def rules_matching_bare_button(sheet)
    stylesheet(sheet).scan(/([^{}]+)\{([^}]*)\}/m).filter_map do |selectors, body|
      next unless selectors.split(",").any? { |part| part.strip == "button" }

      body
    end
  end

  # Declaration body of the first rule matching `pattern`.
  def rule_block(sheet, pattern)
    match = stylesheet(sheet).match(pattern)
    match && match[2]
  end

  # Comments stripped, so a property named in a comment cannot satisfy an
  # assertion — these files carry long explanatory comments naming the very
  # properties under test.
  def stylesheet(sheet)
    path = STYLESHEET_DIR.join(sheet)

    assert_path_exists path
    path.read.gsub(%r{/\*.*?\*/}m, "")
  end
end
