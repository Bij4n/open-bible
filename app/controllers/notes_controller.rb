class NotesController < ApplicationController
  before_action :authenticate_user!
  before_action :load_note, only: %i[show edit update destroy]

  ACTIVE_VISIBILITIES = %w[private_note shared_users shared_groups].freeze

  def show
    respond_to do |format|
      format.html         { render :show }
      format.turbo_stream { render :show }
    end
  end

  def edit
    @highlight_ids = @note.highlights.ids
    respond_to do |format|
      format.html         { render :form, locals: { note: @note, highlight_ids: @highlight_ids } }
      format.turbo_stream { render :form, locals: { note: @note, highlight_ids: @highlight_ids } }
    end
  end

  def new
    highlight_ids = Array(params[:highlight_ids]).map(&:to_i).reject(&:zero?)
    existing = Note.joins(:highlights)
                   .where(user_id: current_user.id, highlights: { id: highlight_ids })
                   .distinct
                   .first

    note = existing || current_user.notes.build(visibility: "private_note")
    ids  = existing ? existing.highlights.ids : current_user.highlights.where(id: highlight_ids).ids
    render :form, locals: { note: note, highlight_ids: ids }
  end

  def create
    highlight_ids = Array(params.dig(:note, :highlight_ids)).map(&:to_i).reject(&:zero?)
    highlights = current_user.highlights.where(id: highlight_ids)
    return head :not_found unless highlights.size == highlight_ids.size

    note = current_user.notes.build(body_param)
    note.visibility = resolved_visibility

    if note.save
      highlights.each { |h| note.highlight_notes.create!(highlight: h) }
      sync_shares(note)
      respond_to_change(note, :created)
    else
      respond_to_failure(note)
    end
  end

  def update
    if @note.update(body_param.merge(visibility: resolved_visibility))
      sync_shares(@note)
      respond_to_change(@note, :ok)
    else
      respond_to_failure(@note)
    end
  end

  def destroy
    @note.destroy
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html         { head :no_content }
      format.json         { head :no_content }
    end
  end

  private

  def load_note
    @note = current_user.notes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def body_param
    params.require(:note).permit(:body)
  end

  # public_note is accepted in the form (Sprint 7 makes it real), but
  # the Sprint 4 UI labels it "Coming in Sprint 7". If the client sends
  # an unknown visibility, fall back to private_note.
  def resolved_visibility
    v = params.dig(:note, :visibility).to_s
    Note.visibilities.key?(v) ? v : "private_note"
  end

  # Reconcile note_shares to match the submitted user_ids / group_ids.
  # Empty arrays mean "unshare from that target type."
  def sync_shares(note)
    user_ids  = sanitized_ids(params.dig(:note, :user_ids)) +
                ids_from_emails(params.dig(:note, :user_emails))
    group_ids = sanitized_ids(params.dig(:note, :group_ids))

    # Only keep shares the current user has standing to share with.
    # Sharing with a group requires the author to be a member; sharing
    # with a user is unrestricted (it's a private-to-you invitation).
    allowed_group_ids = current_user.groups.where(id: group_ids).ids

    desired = user_ids.map { |id| [ "User",  id ] } +
              allowed_group_ids.map { |id| [ "Group", id ] }

    existing = note.note_shares.pluck(:shareable_type, :shareable_id)

    (desired - existing).each do |type, id|
      note.note_shares.create!(shareable_type: type, shareable_id: id)
    end
    (existing - desired).each do |type, id|
      note.note_shares.where(shareable_type: type, shareable_id: id).destroy_all
    end
  end

  def sanitized_ids(raw)
    Array(raw).map(&:to_i).reject(&:zero?)
  end

  # Accepts a comma- or whitespace-separated list of emails and returns
  # matching User ids. Unknown emails are silently dropped — the UI can
  # surface "not found" hints in a later sprint once we have autocomplete.
  def ids_from_emails(raw)
    return [] if raw.blank?

    emails = raw.to_s.downcase.split(/[\s,]+/).reject(&:blank?)
    return [] if emails.empty?

    User.where("lower(email) IN (?)", emails).ids
  end

  def respond_to_change(note, status)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: "", status: status }
      format.html         { head status }
      format.json         { render json: note_payload(note), status: status }
    end
  end

  def respond_to_failure(note)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: "", status: :unprocessable_content }
      format.html         { head :unprocessable_content }
      format.json         { render json: { errors: note.errors }, status: :unprocessable_content }
    end
  end

  def note_payload(note)
    {
      id: note.id,
      body: note.body.to_s,
      visibility: note.visibility,
      user_ids: note.shared_users.ids,
      group_ids: note.shared_groups.ids
    }
  end
end
