# Dumps the browser console log when a JS-driven system spec fails,
# so "expected X, got nothing" becomes diagnosable without hand-
# attaching a debugger. geckodriver doesn't support Selenium's
# :browser log type, so the driver.browser.logs.get call raises and
# is rescued — this effectively no-ops under Firefox. Left in place
# so a future swap to a driver that does support logs (WebKit via
# Playwright, say) picks it up automatically.
RSpec.configure do |config|
  config.after(:each, type: :system, js: true) do |example|
    next unless example.exception

    driver = Capybara.current_session.driver
    next unless driver.respond_to?(:browser)

    logs =
      begin
        driver.browser.logs.get(:browser)
      rescue StandardError
        nil
      end

    next if logs.nil? || logs.empty?

    puts "\n--- browser console (#{example.full_description}) ---"
    logs.each { |entry| puts "  [#{entry.level}] #{entry.message}" }
    puts "--- end browser console ---\n"
  end
end
