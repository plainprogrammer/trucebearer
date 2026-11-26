require "rails_helper"

# Layout rules from spec 020 (the base stylesheet), checked in a real browser.
# Geometry is read in the page with getBoundingClientRect, as in
# docs/specs/020-base-stylesheet/measure.md, which holds the hand-run version.
RSpec.describe "Style guide layout", type: :system do
  # Elements that must be at least 44 by 44 CSS pixels (links in running text are exempt).
  TAPPABLE = ".button, .app-header__name, .list__row, .control, .choice".freeze
  # Chrome reports sub-pixel sizes; measure.md allows half a pixel.
  TOLERANCE = 0.5

  def sizes_of(selector)
    evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(#{selector.to_json})).map((el) => {
        const r = el.getBoundingClientRect();
        return { name: el.className, width: r.width, height: r.height };
      })
    JS
  end

  [ 360, 768 ].each do |width|
    it "makes every tappable control at least 44 by 44 pixels at #{width} pixels wide (AC-1.2)" do
      with_viewport(width) do
        visit "/styleguide"

        controls = sizes_of(TAPPABLE)
        expect(controls).not_to be_empty

        too_small = controls.select { |c| c["width"] < 44 - TOLERANCE || c["height"] < 44 - TOLERANCE }
        expect(too_small).to be_empty, "under 44 by 44: #{too_small.map { |c| "#{c['name']} #{c['width'].round(1)}x#{c['height'].round(1)}" }.join(', ')}"
      end
    end
  end
end
