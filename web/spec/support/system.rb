# System specs: Capybara drives headless Chrome (decision in Issue #72).
# Selenium Manager finds the Chrome driver, so no driver gem is needed.
# Specs live in spec/system and opt in with `type: :system`.

# Selenium Manager sends usage statistics unless told not to.
ENV["SE_AVOID_STATS"] ||= "true"

module ViewportHelper
  # Runs the block with the page laid out at the given CSS size.
  #
  # A desktop Chrome window cannot be made narrower than about 500 pixels, so
  # resizing the window would not give a 360 pixel page. Device metrics
  # emulation sets the real viewport instead: window.innerWidth, media queries,
  # dvh and position: sticky all see this size. It is not full phone emulation
  # (mobile is off, so there is no touch and the viewport meta tag is not
  # applied), which keeps the layout the same as the iframe method in
  # docs/specs/020-base-stylesheet/measure.md. Visit pages inside the block.
  # The override is cleared afterwards, so a failure screenshot is taken at the
  # window size from driven_by, not at this one.
  def with_viewport(width, height = 800)
    browser = page.driver.browser
    browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: false)
    yield
  ensure
    begin
      browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
    rescue Selenium::WebDriver::Error::WebDriverError
      # The browser is gone; keep the original failure rather than hide it.
    end
  end
end

RSpec.configure do |config|
  config.include ViewportHelper, type: :system

  config.before(:each, type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]
  end
end

# Chrome 158 rejects the wildcard origin that Capybara 3.40.0 sends when it
# resets the browser between examples (Storage.clearDataForOrigin with origin
# "*"), so every system spec after the first failed with "* is not a valid
# URL". This shim sends the same clear with real values instead: all cookies
# through Network.clearBrowserCookies, and local storage for the app's own
# origin. Remove it once a Capybara release stops sending "*".
module ChromeResetWithoutWildcardOrigin
  private

  def execute_cdp(cmd, params = {})
    return super unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

    super("Network.clearBrowserCookies")
    types = params[:storageTypes].to_s.split(",") - [ "cookies" ]
    server = Capybara.current_session.server
    if types.any? && server
      super(cmd, origin: "http://#{server.host}:#{server.port}", storageTypes: types.join(","))
    end
  end
end

require "capybara/selenium/driver"
require "capybara/selenium/driver_specializations/chrome_driver"
Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeResetWithoutWildcardOrigin)
