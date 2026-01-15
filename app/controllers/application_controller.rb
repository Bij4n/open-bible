class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_locale

  private

  # TODO (Sprint 2): once users exist, prefer current_user.locale over the
  # session fallback so the choice follows the account across devices.
  def set_locale
    I18n.locale = requested_locale || I18n.default_locale
  end

  def requested_locale
    candidate = params[:locale].presence || session[:locale]
    return unless candidate

    candidate = candidate.to_sym
    return unless I18n.available_locales.include?(candidate)

    session[:locale] = candidate.to_s
    candidate
  end

  def default_url_options
    { locale: I18n.locale == I18n.default_locale ? nil : I18n.locale }
  end
end
