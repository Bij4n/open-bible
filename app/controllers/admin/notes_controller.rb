module Admin
  class NotesController < BaseController
    before_action :load_note, only: %i[show feature unfeature hide unhide]

    def index
      @filter = params[:filter].to_s
      @notes  = filtered_notes.includes(:user, :highlights, :flags).order(created_at: :desc).limit(200)
    end

    def show
    end

    def feature
      @note.feature!(current_user)
      redirect_to admin_notes_path, notice: t("admin.notes.featured_flash")
    end

    def unfeature
      @note.unfeature!
      redirect_to admin_notes_path, notice: t("admin.notes.unfeatured_flash")
    end

    def hide
      @note.hide!(current_user)
      redirect_to admin_notes_path, notice: t("admin.notes.hidden_flash")
    end

    def unhide
      @note.unhide!
      redirect_to admin_notes_path, notice: t("admin.notes.unhidden_flash")
    end

    private

    def load_note
      @note = Note.find(params[:id])
    end

    def filtered_notes
      case @filter
      when "flagged"  then Note.joins(:flags).merge(Flag.unresolved).distinct
      when "featured" then Note.featured
      when "hidden"   then Note.where.not(hidden_at: nil)
      else                 Note.all
      end
    end
  end
end
