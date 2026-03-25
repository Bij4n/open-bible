module Admin
  class FlagsController < BaseController
    def index
      @flags = Flag.unresolved.includes(:user, :flaggable).order(created_at: :desc).limit(200)
    end

    def resolve
      flag = Flag.find(params[:id])
      flag.resolve!(current_user)
      redirect_to admin_flags_path, notice: t("admin.flags.resolved_flash")
    end
  end
end
