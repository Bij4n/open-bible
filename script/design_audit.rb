# Full-app screenshot sweep with headless Firefox. Drives every key surface
# (signed out + signed in, desktop + mobile, light + dark) and drops PNGs in
# tmp/design_audit/ for visual review.
#
#   AUDIT_EMAIL=you@example.com AUDIT_PASSWORD=secret \
#     bundle exec ruby script/design_audit.rb [base_url]
#
# Defaults to http://localhost:3000. The account must already exist.
# Firefox/geckodriver resolution matches spec/rails_helper.rb: FIREFOX_BINARY
# and GECKODRIVER_PATH env vars, falling back to the ~/.local/opt tarballs.

require "selenium-webdriver"
require "fileutils"

BASE = ARGV[0] || "http://localhost:3000"
OUT  = File.expand_path("../tmp/design_audit", __dir__)
EMAIL    = ENV.fetch("AUDIT_EMAIL")
PASSWORD = ENV.fetch("AUDIT_PASSWORD")
FileUtils.mkdir_p(OUT)

def make_driver(width:, height:)
  options = Selenium::WebDriver::Firefox::Options.new
  options.binary = ENV.fetch("FIREFOX_BINARY", File.expand_path("~/.local/opt/firefox/firefox"))
  options.add_argument("-headless")
  options.add_argument("--width=#{width}")
  options.add_argument("--height=#{height}")
  service = Selenium::WebDriver::Service.firefox(
    path: ENV.fetch("GECKODRIVER_PATH", File.expand_path("~/.local/opt/geckodriver"))
  )
  Selenium::WebDriver.for(:firefox, options: options, service: service)
end

def shoot(driver, path, name, dark: false, wait: 1.2)
  driver.navigate.to("#{BASE}#{path}")
  sleep wait
  if dark
    driver.execute_script("document.documentElement.setAttribute('data-theme','dark')")
    sleep 0.5
  end
  driver.save_screenshot("#{OUT}/#{name}.png")
  puts "captured #{name} (#{driver.title})"
rescue => e
  puts "FAILED #{name}: #{e.class} #{e.message}"
end

def sign_in(driver)
  driver.navigate.to("#{BASE}/users/sign_in")
  sleep 1
  driver.find_element(id: "user_email").send_keys(EMAIL)
  driver.find_element(id: "user_password").send_keys(PASSWORD)
  driver.find_element(css: "form input[type=submit], form button[type=submit]").click
  sleep 1.5
end

d = make_driver(width: 1440, height: 1000)
shoot(d, "/", "01-home")
shoot(d, "/how-it-works", "02-how-it-works")
shoot(d, "/users/sign_in", "03-sign-in")
shoot(d, "/public/bible/kjv/john/3", "04-public-bible")
shoot(d, "/search?q=love", "05-search")
sign_in(d)
shoot(d, "/bible/kjv/john/3", "06-reader-kjv")
shoot(d, "/bible/rv1909/john/3", "07-reader-rv1909")
shoot(d, "/groups", "08-groups")
shoot(d, "/notes", "09-notes")
shoot(d, "/settings", "10-settings")
shoot(d, "/bible/kjv/john/3", "11-reader-dark", dark: true)
shoot(d, "/", "12-home-dark", dark: true)
d.quit

m = make_driver(width: 390, height: 844)
shoot(m, "/", "20-home-mobile")
shoot(m, "/public/bible/kjv/john/3", "21-public-bible-mobile")
sign_in(m)
shoot(m, "/bible/kjv/john/3", "22-reader-mobile")
m.quit

puts "done -> #{OUT}"
