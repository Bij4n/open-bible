class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_locale

  helper_method :resolved_theme

  # Returns "light" / "dark" when the signed-in user has a concrete
  # preference, nil otherwise. Used by the layout to set data-theme on the
  # server so first paint doesn't flash the wrong palette. When nil, the
  # theme Stimulus controller falls back to localStorage / system scheme.
  def resolved_theme
    return nil unless user_signed_in?

    theme = current_user.theme
    %w[light dark].include?(theme) ? theme : nil
  end

  private

  # Locale precedence: signed-in user's preference > session > params > default.
  # For signed-out users, params[:locale] from the header language switcher
  # writes through to the session so the choice survives across requests.
  def set_locale
    I18n.locale = resolved_locale
  end

  def resolved_locale
    if user_signed_in? && User::UI_LOCALES.include?(current_user.ui_locale)
      return current_user.ui_locale.to_sym
    end

    if (candidate = params[:locale].presence) && available_locale?(candidate)
      session[:locale] = candidate
    end

    stored = session[:locale]
    available_locale?(stored) ? stored.to_sym : I18n.default_locale
  end

  def available_locale?(code)
    code.present? && I18n.available_locales.map(&:to_s).include?(code.to_s)
  end

  def default_url_options
    { locale: I18n.locale == I18n.default_locale ? nil : I18n.locale }
  end
end
