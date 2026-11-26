require "rails_helper"

# Layout rules from spec 020 (the base stylesheet), checked in a real browser.
# Geometry is read in the page with getBoundingClientRect, as in
# docs/specs/020-base-stylesheet/measure.md, which holds the hand-run version.
RSpec.describe "Style guide layout", type: :system do
  # Elements that must be at least 44 by 44 CSS pixels (links in running text are exempt).
  tappable = [ ".button", ".app-header__name", ".list__row", ".control", ".choice", ".power-tile:not(.power-tile--taken)", ".segmented__label" ]
  # Things in the main column that a person can focus.
  focusable = "a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled])"
  # Chrome reports sub-pixel sizes; measure.md allows half a pixel.
  tolerance = 0.5

  [ 360, 768 ].each do |width|
    it "shows a focus ring on the keyboard-focused segmented option at #{width} pixels wide (spec 027 AC-9.4)" do
      with_viewport(width) do
        visit "/styleguide"
        find("section[data-component=segmented] input[value=army]", match: :first, visible: :all).send_keys(:tab)
        ring = evaluate_script("(() => { const input = document.querySelector('section[data-component=segmented] input:focus'); return input && getComputedStyle(input.nextElementSibling).outlineStyle; })()")

        expect(ring).to eq("solid")
      end
    end

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

  describe "the phase header, banner and confirmation page (spec 022)" do
    it "sets the phase header in mono capitals with the badge at the end of the row, and nothing scrolls sideways (AC-8.1)" do
      with_viewport(360) do
        visit "/styleguide"
        expect(page).to have_css(".phase-header .power-badge")

        read = evaluate_script(<<~JS)
          (() => {
            const header = Array.from(document.querySelectorAll(".phase-header")).find((el) => el.querySelector(".power-badge"));
            const title = header.querySelector(".phase-header__title");
            const badge = header.querySelector(".power-badge");
            const style = getComputedStyle(title);
            return {
              transform: style.textTransform,
              family: style.fontFamily,
              source: title.textContent,
              titleRight: title.getBoundingClientRect().right,
              badgeLeft: badge.getBoundingClientRect().left,
              badgeRight: badge.getBoundingClientRect().right,
              rowRight: header.getBoundingClientRect().right,
              scroll: document.documentElement.scrollWidth,
              client: document.documentElement.clientWidth
            };
          })()
        JS

        expect(read["transform"]).to eq("uppercase")
        expect(read["family"]).to include("Plex Mono")
        expect(read["source"]).to eq("Spring 1901 · Movement") # sentence case in the source; the stylesheet draws capitals
        expect(read["badgeLeft"]).to be >= read["titleRight"] - 0.5
        expect(read["badgeRight"]).to be <= read["rowRight"] + 0.5
        expect(read["scroll"]).to be <= read["client"]
      end
    end

    it "gives every confirmation button and link at least 44 by 44 pixels, and draws the banner kinds apart (AC-8.3, 8.2)" do
      with_viewport(360) do
        visit "/styleguide"
        expect(page).to have_css(".confirm .button")
        expect(page).to have_css(".banner--info")

        sizes = evaluate_script(<<~JS)
          Array.from(document.querySelectorAll(".confirm .button")).map((el) => {
            const r = el.getBoundingClientRect();
            return { width: r.width, height: r.height };
          })
        JS
        expect(sizes).not_to be_empty
        expect(sizes.select { |s| s["width"] < 43.5 || s["height"] < 43.5 }).to be_empty

        edges = evaluate_script(<<~JS)
          ["info", "warning", "danger"].map((kind) => {
            const style = getComputedStyle(document.querySelector(".banner--" + kind));
            return { kind: kind, border: style.borderTopColor, background: style.backgroundColor };
          })
        JS
        expect(edges.map { |e| [ e["border"], e["background"] ] }.uniq.size).to eq(3)
      end
    end
  end

  describe "the join code, power tiles and QR card (spec 021)" do
    it "sets the join code in mono at least as large as the 2xl step, on one line that fits (AC-9.7)" do
      with_viewport(360) do
        visit "/styleguide"
        expect(page).to have_css(".join-code")

        codes = evaluate_script(<<~JS)
          (() => {
            const probe = document.createElement("span");
            probe.className = "sg-type-step--2xl";
            document.body.appendChild(probe);
            const step = parseFloat(getComputedStyle(probe).fontSize);
            probe.remove();
            return Array.from(document.querySelectorAll(".join-code")).map((el) => {
              const style = getComputedStyle(el);
              return {
                mono: el.classList.contains("mono"),
                size: parseFloat(style.fontSize),
                step: step,
                fits: el.scrollWidth <= el.clientWidth,
                height: el.getBoundingClientRect().height,
                lineHeight: parseFloat(style.lineHeight)
              };
            });
          })()
        JS

        expect(codes).not_to be_empty
        codes.each do |code|
          expect(code["mono"]).to be(true)
          expect(code["size"]).to be >= code["step"]
          expect(code["fits"]).to be(true)
          expect(code["height"]).to be < 1.5 * code["lineHeight"]
        end
      end
    end

    it "draws a taken tile dashed, white and muted, and an open tile solid (AC-9.3)" do
      with_viewport(360) do
        visit "/styleguide"
        expect(page).to have_css(".power-tile--taken")
        expect(page).to have_css("button.power-tile")

        read = evaluate_script(<<~JS)
          (() => {
            const taken = getComputedStyle(document.querySelector(".power-tile--taken"));
            const open = getComputedStyle(document.querySelector("button.power-tile"));
            return {
              takenBorder: taken.borderTopStyle,
              takenBackground: taken.backgroundColor,
              takenColor: taken.color,
              mutedColor: getComputedStyle(document.querySelector(".text-muted")).color,
              openBorder: open.borderTopStyle
            };
          })()
        JS

        expect(read["takenBorder"]).to eq("dashed")
        expect(read["takenBackground"]).to eq("rgb(255, 255, 255)")
        expect(read["takenColor"]).to eq(read["mutedColor"])
        expect(read["openBorder"]).to eq("solid")
      end
    end

    it "puts each QR code on white, at least 200 pixels wide, with a four-module quiet zone (AC-9.8)" do
      with_viewport(360) do
        visit "/styleguide"
        expect(page).to have_css(".qr-card .qr-card__code path")

        cards = evaluate_script(<<~JS)
          Array.from(document.querySelectorAll(".qr-card")).map((card) => {
            const svg = card.querySelector(".qr-card__code");
            const path = svg.querySelector("path").getBoundingClientRect();
            const box = svg.getBoundingClientRect();
            const scale = box.width / svg.viewBox.baseVal.width;
            return {
              background: getComputedStyle(card).backgroundColor,
              width: box.width,
              left: (path.left - box.left) / scale,
              top: (path.top - box.top) / scale,
              right: (box.right - path.right) / scale,
              bottom: (box.bottom - path.bottom) / scale
            };
          })
        JS

        expect(cards).not_to be_empty
        cards.each do |card|
          expect(card["background"]).to eq("rgb(255, 255, 255)")
          expect(card["width"]).to be >= 200
          %w[left top right bottom].each { |side| expect(card[side]).to be >= 4 - 0.05, "quiet zone on the #{side}: #{card[side]}" }
        end
      end
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
