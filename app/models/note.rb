class Note < ApplicationRecord
  include GroupBibleBroadcastable

  # :private and :public clash with Ruby keywords and Rails generated
  # enum methods (note.private? etc). Keeping the stored values as
  # private_note / public_note. The UI still labels them "Private" /
  # "Public".
  VISIBILITIES = {
    private_note:  0,
    shared_users:  1,
    shared_groups: 2,
    public_note:   3
  }.freeze

  enum :visibility, VISIBILITIES

  has_rich_text :body

  belongs_to :user
  has_many :highlight_notes, dependent: :destroy
  has_many :highlights, through: :highlight_notes

  has_many :note_shares, dependent: :destroy
  has_many :shared_users,  through: :note_shares, source: :shareable, source_type: "User"
  has_many :shared_groups, through: :note_shares, source: :shareable, source_type: "Group"

  has_many :comments, dependent: :destroy

  validates :body, presence: true

  # Notes the user is allowed to see:
  #   - their own notes, any visibility
  #   - notes shared directly with them via NoteShare (shareable: user)
  #   - notes shared with any group they belong to (shareable: group)
  #   - public notes (Sprint 7 will expose these; the clause is active
  #     now so the public-bible reader can query the same scope)
  scope :visible_to, ->(user) {
    next where("1=0") unless user # anonymous visitors see nothing private-bucket-ish

    group_ids = user.groups.ids
    where(<<~SQL.squish, uid: user.id, gids: group_ids.presence || [ 0 ], public_visibility: visibilities[:public_note])
      notes.user_id = :uid
      OR notes.id IN (
        SELECT note_id FROM note_shares
        WHERE shareable_type = 'User' AND shareable_id = :uid
      )
      OR notes.id IN (
        SELECT note_id FROM note_shares
        WHERE shareable_type = 'Group' AND shareable_id IN (:gids)
      )
      OR notes.visibility = :public_visibility
    SQL
  }

  # Notes shared with a specific Group (not a full visibility check —
  # use this in the group Bible reader where membership has already been
  # confirmed upstream).
  scope :shared_with_group, ->(group) {
    joins(:note_shares).where(note_shares: { shareable_type: "Group", shareable_id: group.id })
  }

  # Body edits re-render the list entry on every group this note is
  # shared with. Destroy cascades via note_shares' callbacks.
  after_update_commit :broadcast_note_update, if: :saved_change_to_body?

  private

  def saved_change_to_body?
    # ActionText body updates arrive through the rich_text record; plain
    # AR dirty tracking on `body` isn't available, so fall back to "any
    # update commit fires this". Conservative but correct.
    true
  end

  def broadcast_note_update
    return if shared_groups.empty?

    shared_groups.each do |group|
      target_chapters_for(self).each do |verse|
        Turbo::StreamsChannel.broadcast_replace_to(
          group, "bible", verse[:translation], verse[:book], verse[:chapter],
          target: ActionView::RecordIdentifier.dom_id(self),
          partial: "groups/bible/note",
          locals: { note: self }
        )
      end
    end
  end
end
