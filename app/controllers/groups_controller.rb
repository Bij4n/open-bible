class GroupsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_group, only: %i[show edit update destroy leave]
  before_action :ensure_group_member, only: %i[show]
  before_action :ensure_group_owner,  only: %i[edit update destroy]

  skip_before_action :authenticate_user!, only: [ :discover ]

  def index
    @groups = current_user.groups.distinct.order(:name)
  end

  def discover
    @groups = Group.where(privacy: :open_group)
                   .includes(:memberships)
                   .order(:name)
  end

  def new
    @group = Group.new
  end

  def create
    @group = current_user.owned_groups.build(group_params)
    @group.invitation_code ||= Group.generate_invitation_code
    if @group.save
      redirect_to @group, notice: t("groups.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @memberships = @group.memberships.includes(:user)
    @pending_invitations = @group.group_invitations.pending.order(created_at: :desc) if @group.owner_id == current_user.id
  end

  def edit
  end

  def update
    if @group.update(group_params)
      redirect_to @group, notice: t("groups.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @group.destroy
    redirect_to groups_path, notice: t("groups.destroyed"), status: :see_other
  end

  def join
    if params[:group_id].present?
      join_open_group
    else
      join_by_code
    end
  end

  def leave
    membership = @group.memberships.find_by(user: current_user)
    if membership.nil?
      redirect_to groups_path and return
    end

    begin
      membership.destroy!
      redirect_to groups_path, notice: t("groups.left"), status: :see_other
    rescue ActiveRecord::RecordInvalid
      redirect_to group_path(@group), alert: t("groups.last_owner_cant_leave")
    end
  end

  private

  def join_open_group
    group = Group.find_by(id: params[:group_id], privacy: :open_group)
    if group.nil?
      redirect_to discover_groups_path, alert: t("groups.not_found") and return
    end
    group.memberships.find_or_create_by!(user: current_user) { |m| m.role = :member }
    redirect_to group_path(group), notice: t("groups.joined")
  end

  def join_by_code
    code = params[:invitation_code].to_s.strip.upcase
    group = Group.find_by(invitation_code: code)
    if group.nil?
      redirect_to groups_path, alert: t("groups.invalid_code") and return
    end
    group.memberships.find_or_create_by!(user: current_user) { |m| m.role = :member }
    redirect_to group_path(group), notice: t("groups.joined")
  end

  def load_group
    @group = Group.find(params[:id])
  end

  def ensure_group_member
    head :not_found unless @group.member?(current_user)
  end

  def ensure_group_owner
    head :not_found unless @group.owner_id == current_user.id
  end

  def group_params
    params.require(:group).permit(:name, :description, :privacy)
  end
end
