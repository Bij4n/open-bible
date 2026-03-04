class MembershipsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_group
  before_action :ensure_group_owner

  def create
    email = params[:email].to_s.downcase.strip
    user = User.find_by("lower(email) = ?", email)

    if user.nil?
      redirect_to group_path(@group), alert: t("memberships.user_not_found", email: email) and return
    end

    @group.memberships.find_or_create_by!(user: user) { |m| m.role = :member }
    redirect_to group_path(@group), notice: t("memberships.added", email: email)
  end

  def destroy
    membership = @group.memberships.find(params[:id])
    membership.destroy!
    redirect_to group_path(@group), notice: t("memberships.removed"), status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_to group_path(@group), alert: t("memberships.cannot_remove_last_owner")
  end

  private

  def load_group
    @group = Group.find(params[:group_id])
  end

  def ensure_group_owner
    head :not_found unless @group.owner_id == current_user.id
  end
end
