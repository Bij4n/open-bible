class Highlight < ApplicationRecord
  include GroupBibleBroadcastable
  # Muted manuscript-appropriate tones. Specific hex values live in the
  # CSS (app/assets/tailwind/application.css) so light and dark mode
  # overlays can be tuned independently.
  COLORS = %w[gold rose sage lavender sky].freeze

  enum :color, COLORS.each_with_index.to_h

  belongs_to :user
  belongs_to :translation

  has_many :highlight_notes, dependent: :destroy
  has_many :notes, through: :highlight_notes

  validates :osis_ref, presence: true
  validates :user_id, uniqueness: { scope: [ :osis_ref, :color ] }
  validate  :osis_ref_is_parseable

  scope :for_chapter, ->(prefix) { where("osis_ref LIKE ?", "#{sanitize_sql_like(prefix)}%") }

  # Highlights from translations OTHER than the current one that touch
  # this chapter. Sprint 10 surfaces these as a bridge badge so a user
  # reading RV1909 can see which verses they've annotated in KJV. We
  # can't render character ranges across translations (offsets differ),
  # so this scope is intentionally verse-granular — the view uses the
  # matched refs' affected-verses list to pick which verses to badge.
  scope :from_other_translations_in_chapter, ->(translation_code:, book:, chapter:) {
    same_chapter_pattern = "Bible.%.#{sanitize_sql_like(book.to_s)}.#{sanitize_sql_like(chapter.to_s)}.%"
    current_prefix       = "Bible.#{sanitize_sql_like(translation_code.to_s)}.%"
    where("osis_ref LIKE ?", same_chapter_pattern)
      .where.not("osis_ref LIKE ?", current_prefix)
  }

  # If this highlight is anchored to a note shared with one or more
  # groups, members of those groups viewing the same chapter should see
  # the verse re-rendered. Private highlights don't broadcast.
  after_create_commit  :broadcast_affected_verses_to_groups
  after_update_commit  :broadcast_affected_verses_to_groups
  # highlight_notes cascade via dependent: :destroy, so we lose access
  # to shared_groups by the time after_destroy_commit fires — snapshot
  # the targets before the cascade runs.
  before_destroy       :snapshot_broadcast_targets
  after_destroy_commit :broadcast_destroy

  def parsed_ref
    @parsed_ref ||= OsisRef.parse(osis_ref, strict: :same_chapter)
  end

  def affected_verses
    Verse.where(osis_ref: parsed_ref.verse_osis_refs).includes(chapter: { book: :translation })
  end

  def groups_broadcasting_this
    notes.flat_map(&:shared_groups).uniq
  end

  private

  def broadcast_affected_verses_to_groups
    broadcast_verse_replace_to_groups(groups_broadcasting_this, affected_verses.to_a)
  end

  def snapshot_broadcast_targets
    @broadcast_groups_snapshot = groups_broadcasting_this.to_a
    @broadcast_verses_snapshot = affected_verses.to_a
  end

  def broadcast_destroy
    broadcast_verse_replace_to_groups(
      @broadcast_groups_snapshot || [],
      @broadcast_verses_snapshot || []
    )
  end

  private

  def osis_ref_is_parseable
    return if osis_ref.blank?

    OsisRef.parse(osis_ref, strict: :same_chapter)
  rescue OsisRef::ParseError => e
    errors.add(:osis_ref, e.message)
  end
end
