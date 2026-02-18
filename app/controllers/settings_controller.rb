class SettingsController < ApplicationController
  before_action :authenticate_user!

  def edit
  end

  def update
    if current_user.update(settings_params)
      respond_to do |format|
        format.json { head :no_content }
        format.html do
          if inside_settings_frame?
            flash.now[:notice] = t("settings.updated")
            render :edit, status: :ok
          else
            redirect_back fallback_location: settings_path, notice: t("settings.updated")
          end
        end
      end
    else
      respond_to do |format|
        format.json { render json: { errors: current_user.errors }, status: :unprocessable_content }
        format.html do
          flash.now[:alert] = current_user.errors.full_messages.to_sentence
          render :edit, status: :unprocessable_content
        end
      end
    end
  end

  private

  # Per-section forms each submit only the fields they control, so we
  # allow the full set here and let the form decide.
  def settings_params
    params.require(:user).permit(:ui_locale, :theme, :default_translation_id, :display_name)
  end

  # Turbo Frame submissions from the /settings page carry a Turbo-Frame
  # header naming the section. Without it (e.g. the header's language
  # button_to), we want a full-page redirect back.
  def inside_settings_frame?
    request.headers["Turbo-Frame"].to_s.start_with?("settings_")
  end
end
