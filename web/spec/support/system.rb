# System specs: Capybara drives headless Chrome (decision in Issue #72).
# Selenium Manager finds the Chrome driver, so no driver gem is needed.
# Specs live in spec/system and opt in with `type: :system`.
# Selenium Manager sends usage statistics unless told not to.
ENV["SE_AVOID_STATS"] ||= "true"

module ViewportHelper
  # Runs the block with the page laid out at the given CSS size, as on a phone.
  #
  # A desktop Chrome window cannot be made narrower than about 500 pixels, so
  # resizing the window would not give a 360 pixel page. Device metrics
  # emulation sets the real viewport instead: window.innerWidth, media queries,
  # dvh and position: sticky all see this size. The override is cleared
  # afterwards, and visit pages inside the block.
  def with_viewport(width, height = 800)
    browser = page.driver.browser
    browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: false)
    yield
  ensure
    browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end

RSpec.configure do |config|
  config.include ViewportHelper, type: :system

  config.before(:each, type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]
  end
end
