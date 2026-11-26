require "rails_helper"

# Layout rules from spec 020 (the base stylesheet), checked in a real browser.
# Geometry is read in the page with getBoundingClientRect, as in
# docs/specs/020-base-stylesheet/measure.md, which holds the hand-run version.
RSpec.describe "Style guide layout", type: :system do
  # Elements that must be at least 44 by 44 CSS pixels (links in running text are exempt).
  tappable = [ ".button", ".app-header__name", ".list__row", ".control", ".choice" ]
  # Things in the main column that a person can focus.
  focusable = "a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled])"
  # Chrome reports sub-pixel sizes; measure.md allows half a pixel.
  tolerance = 0.5

  [ 360, 768 ].each do |width|
    it "makes every tappable control at least 44 by 44 pixels at #{width} pixels wide (AC-1.2)" do
      with_viewport(width) do
        visit "/styleguide"
        expect(evaluate_script("window.innerWidth")).to eq(width)

        # Each selector must find something, or a renamed class would quietly shrink the check.
        tappable.each { |selector| expect(page).to have_css(selector) }

        controls = evaluate_script(<<~JS)
          Array.from(document.querySelectorAll(#{tappable.join(", ").to_json})).map((el) => {
            const r = el.getBoundingClientRect();
            return { name: el.className, width: r.width, height: r.height };
          })
        JS

        too_small = controls.select { |c| c["width"] < 44 - tolerance || c["height"] < 44 - tolerance }
        expect(too_small).to be_empty, "under 44 by 44: #{too_small.map { |c| "#{c['name']} #{c['width'].round(1)}x#{c['height'].round(1)}" }.join(', ')}"
      end
    end
  end

  it "has no horizontal scroll at 360 pixels wide (AC-1.2)" do
    with_viewport(360) do
      visit "/styleguide"
      expect(evaluate_script("window.innerWidth")).to eq(360)

      widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
      expect(widths["scroll"]).to be <= widths["client"]
    end
  end

  describe "the action area at the bottom of the screen" do
    it "stays fixed to the bottom of the viewport as the page scrolls, and the content scrolls clear of it (AC-3.2, AC-3.3, AC-3.10)" do
      with_viewport(360) do
        visit "/styleguide"
        expect(evaluate_script("getComputedStyle(document.querySelector('.app-actions')).position")).to eq("sticky")

        # At the top, the middle and the end of the page.
        positions = [ "0", "document.documentElement.scrollHeight / 2", "document.documentElement.scrollHeight" ]
        readings = positions.map do |top|
          evaluate_script(<<~JS)
            (() => {
              window.scrollTo(0, #{top});
              const bar = document.querySelector('.app-actions').getBoundingClientRect();
              return {
                gap: window.innerHeight - bar.bottom,
                clear: document.querySelector('.app-main').lastElementChild.getBoundingClientRect().bottom - bar.top,
                headerTop: document.querySelector('.app-header').getBoundingClientRect().top
              };
            })()
          JS
        end

        # The area sits on the bottom edge wherever the page is scrolled to (AC-3.2).
        expect(readings.map { |r| r["gap"] }).to all(be_within(tolerance).of(0))
        # At the end, the last of the content ends at or above the area (AC-3.3).
        expect(readings.last["clear"]).to be <= tolerance
        # Once scrolled, the header has gone out of view with the content (AC-3.10).
        expect(readings.last["headerTop"]).to be < 0
      end
    end

    it "does not cover the control that has the focus (AC-3.6)" do
      with_viewport(360) do
        visit "/styleguide"

        # Put each control 10 pixels below the top of the area, so it is hidden
        # behind it, then focus it. The browser must scroll it clear of the area.
        # The style guide's area is one row of buttons, which is the height the
        # spec sizes the scroll padding for, so "clear" means the whole control.
        # A control that will not take focus is reported, not skipped.
        result = evaluate_script(<<~JS)
          (() => {
            const bar = document.querySelector('.app-actions');
            const checked = [], covered = [], unfocusable = [];
            for (const el of document.querySelectorAll(`.app-main :is(#{focusable})`)) {
              if (!el.getClientRects().length) continue;
              const name = el.className || el.tagName;
              window.scrollBy(0, el.getBoundingClientRect().top - (bar.getBoundingClientRect().top + 10));
              if (el.getBoundingClientRect().bottom <= bar.getBoundingClientRect().top) continue; // could not be hidden here
              el.focus();
              if (document.activeElement !== el) { unfocusable.push(name); continue; }
              checked.push(name);
              if (el.getBoundingClientRect().bottom > bar.getBoundingClientRect().top + #{tolerance}) covered.push(name);
            }
            return { checked: checked.length, covered, unfocusable };
          })()
        JS

        expect(result["unfocusable"]).to be_empty
        # The check must have something to check, or it passes for nothing.
        expect(result["checked"]).to be >= 10
        expect(result["covered"]).to be_empty
      end
    end
  end
end
