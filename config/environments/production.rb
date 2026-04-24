require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Render terminates TLS at the edge and forwards HTTP to the container; without
  # assume_ssl, force_ssl would redirect-loop because Rails never sees an https URL.
  config.assume_ssl = true
  config.force_ssl = true

  # The load balancer health-checks over HTTP; skip the redirect for /up so it
  # doesn't flap on every probe.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "bible-together.org", protocol: "https" }

  # Deliver mail via Resend's SMTP endpoint. API key lives in Rails
  # encrypted credentials as smtp.resend.api_key — add via
  # `bin/rails credentials:edit` before the first production deploy
  # of this change. Without the credential, SMTP auth fails and
  # Rails raises (see raise_delivery_errors below), which is how the
  # deploy log will surface a missing key.
  #
  # raise_delivery_errors: true is deliberately opposite to Rails'
  # default. Silent delivery failure is what produced the current bug;
  # loud failure gets noticed in logs and observability. If Resend
  # has an outage, password-reset submissions will return 500 —
  # preferable to pretending the email sent and leaving users locked
  # out.
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.smtp_settings = {
    address: "smtp.resend.com",
    port: 465,
    tls: true,
    user_name: "resend",
    password: Rails.application.credentials.dig(:smtp, :resend, :api_key),
    domain: "bible-together.org"
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  config.hosts = [
    "bible-together.org",
    "www.bible-together.org",
    /.*\.onrender\.com/
  ]

  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
