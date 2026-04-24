# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require 'rspec/rails'
require 'capybara/rails'
require 'capybara/rspec'
require 'shoulda/matchers'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

# Ensures that the test database schema matches the current schema file.
# If there are pending migrations it will invoke `db:test:prepare` to
# recreate the test database by loading the schema.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails uses metadata to mix in different behaviours to your tests,
  # for example enabling you to call `get` and `post` in request specs. e.g.:
  #
  #     RSpec.describe UsersController, type: :request do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/8-0/rspec-rails
  #
  # You can also infer these behaviours automatically by location, e.g.
  # /spec/models would pull in the same behaviour as `type: :model` but this
  # behaviour is considered legacy and will be removed in a future version.
  #
  # To enable this behaviour uncomment the line below.
  # config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  config.include FactoryBot::Syntax::Methods
  config.include Capybara::DSL, type: :system
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system

  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :headless_firefox_ci
  end

  # VerseEmbedding memoises parsed vectors in class state for performance.
  # Transactional fixtures roll back DB writes between specs but don't
  # touch class state, so any spec that queries the cache after another
  # spec created embeddings would see rolled-back rows. Reset every
  # example to keep them independent.
  config.before(:each) do
    VerseEmbedding.reset_cache! if defined?(VerseEmbedding)
  end

  # Rebuild the Tailwind CSS bundle once before the suite runs IF
  # system specs are in this invocation. System specs exercise the
  # compiled bundle at app/assets/builds/application.css (which is
  # gitignored); a source-CSS change without a manual rebuild would
  # pass false-green — the exact failure mode that hid the
  # verse-number contrast regression until axe caught it manually.
  # Unit / request / helper runs skip this hook so they stay fast.
  config.before(:suite) do
    has_system_specs = RSpec.world.filtered_examples.values.flatten.any? do |example|
      example.metadata[:type] == :system
    end
    if has_system_specs
      output = `cd #{Rails.root} && bundle exec rails tailwindcss:build 2>&1`
      abort "Tailwind build failed before system specs:\n#{output}" unless $?.success?
    end
  end
end

# Headless Firefox + geckodriver. Uses a local Mozilla-tarball install
# at ~/.local/opt/firefox and matching geckodriver rather than system
# snap packages, because snap-confined Firefox and snap-confined
# geckodriver can't hand off through the /usr/bin/firefox transitional
# shim. Paths are overridable via FIREFOX_BINARY / GECKODRIVER_PATH
# env vars so CI (different install layout) can point them elsewhere.
Capybara.register_driver(:headless_firefox_ci) do |app|
  firefox_binary   = ENV.fetch("FIREFOX_BINARY",   File.expand_path("~/.local/opt/firefox/firefox"))
  geckodriver_path = ENV.fetch("GECKODRIVER_PATH", File.expand_path("~/.local/opt/geckodriver"))

  options = Selenium::WebDriver::Firefox::Options.new
  options.binary = firefox_binary
  options.add_argument("-headless")
  options.add_argument("--width=1400")
  options.add_argument("--height=1400")

  service = Selenium::WebDriver::Firefox::Service.new(path: geckodriver_path)

  Capybara::Selenium::Driver.new(app, browser: :firefox, options: options, service: service)
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
