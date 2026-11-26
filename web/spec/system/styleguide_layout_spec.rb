require "rails_helper"

# Layout rules from spec 020 (the base stylesheet), checked in a real browser.
# Geometry is read in the page with getBoundingClientRect, as in
# docs/specs/020-base-stylesheet/measure.md, which holds the hand-run version.
RSpec.describe "Style guide layout", type: :system do
  # Elements that must be at least 44 by 44 CSS pixels (links in running text are exempt).
  tappable = ".button, .app-header__name, .list__row, .control, .choice"
  # Things in the main column that a person can focus.
  focusable = "a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled])"
  # Chrome reports sub-pixel sizes; measure.md allows half a pixel.
  tolerance = 0.5

  [ 360, 768 ].each do |width|
    it "makes every tappable control at least 44 by 44 pixels at #{width} pixels wide (AC-1.2)" do
      with_viewport(width) do
        visit "/styleguide"
        expect(evaluate_script("window.innerWidth")).to eq(width)

        controls = evaluate_script(<<~JS)
          Array.from(document.querySelectorAll(#{tappable.to_json})).map((el) => {
            const r = el.getBoundingClientRect();
            return { name: el.className, width: r.width, height: r.height };
          })
        JS
        expect(controls).not_to be_empty

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

  describe "the action area at the bottom of the screen (AC-3.2, AC-3.3, AC-3.6, AC-3.10)" do
    it "stays fixed to the bottom of the viewport as the page scrolls" do
      with_viewport(360) do
        visit "/styleguide"
        expect(evaluate_script("getComputedStyle(document.querySelector('.app-actions')).position")).to eq("sticky")

        # Gap between the bottom of the area and the bottom of the viewport, at the top, middle and end of the page.
        gaps = %w[0 (document.documentElement.scrollHeight/2) document.documentElement.scrollHeight].map do |top|
          evaluate_script(<<~JS)
            (() => {
              window.scrollTo(0, #{top});
              return window.innerHeight - document.querySelector('.app-actions').getBoundingClientRect().bottom;
            })()
          JS
        end
        expect(gaps).to all(be_within(tolerance).of(0))
      end
    end

    it "does not cover the control that has the focus" do
      with_viewport(360) do
        visit "/styleguide"

        # Put each control 10 pixels below the top of the area, so it is hidden
        # behind it, then focus it. The browser must scroll it clear of the area.
        result = evaluate_script(<<~JS)
          (() => {
            const bar = document.querySelector('.app-actions');
            const hidden = [], covered = [];
            for (const el of document.querySelectorAll(`.app-main :is(#{focusable})`)) {
              if (!el.getClientRects().length) continue;
              window.scrollBy(0, el.getBoundingClientRect().top - (bar.getBoundingClientRect().top + 10));
              if (el.getBoundingClientRect().bottom <= bar.getBoundingClientRect().top) continue; // could not be hidden here
              hidden.push(el.className);
              el.focus();
              if (document.activeElement !== el) continue;
              if (el.getBoundingClientRect().bottom > bar.getBoundingClientRect().top + #{tolerance}) covered.push(el.className || el.tagName);
            }
            return { hidden: hidden.length, covered };
          })()
        JS

        # The check must have something to check, or it passes for nothing.
        expect(result["hidden"]).to be >= 10
        expect(result["covered"]).to be_empty
      end
    end
  end
end
