require "webmock/rspec"

# Block outbound HTTP by default so a forgotten real-world request
# shows up as a failing spec rather than a flake. Localhost stays
# open so Selenium / Capybara drivers can reach the app server.
WebMock.disable_net_connect!(allow_localhost: true)
