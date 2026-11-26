require "rails_helper"

RSpec.describe "The font in the browser", type: :system do
  before { visit "/styleguide" }

  def load_font = page.evaluate_async_script(%(const done = arguments[0]; document.fonts.load('1rem "Plex Mono"').then((f) => done(f.length));))

  it "really loads the one face (AC-8.2)" do
    expect(load_font).to eq(1)
  end

  it "makes every request to this app, with the one font file as the only font (AC-6.3)" do
    load_font
    entries = evaluate_script("performance.getEntriesByType('resource').map((e) => e.name)")
    origin = evaluate_script("window.location.origin")
    expect(entries).not_to be_empty
    expect(entries).to all(start_with(origin))
    expect(entries.grep(/\.(woff2?|ttf|otf)(\?|\z)/).size).to eq(1)
    expect(entries.grep(/\.woff2\z/).size).to eq(1)
  end
end
