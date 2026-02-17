class SettingsController < ApplicationController
  before_action :authenticate_user!

  def edit
  end

  def update
    if current_user.update(settings_params)
      flash.now[:notice] = t("settings.updated")
      render :edit, status: :ok
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  # Per-section forms each submit only the fields they control, so we
  # allow the full set here and let the form decide.
  def settings_params
    params.require(:user).permit(:ui_locale, :theme, :default_translation_id, :display_name)
  end
end
