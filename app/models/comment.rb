class Comment < ApplicationRecord
  MAX_DEPTH = 3
  BODY_MAX  = 2_000

  belongs_to :note
  belongs_to :user
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  validates :body, presence: true, length: { maximum: BODY_MAX }
  validate  :parent_is_not_self

  # Sibling-on-overflow: a reply to a depth-MAX comment becomes a sibling
  # of that comment (child of its parent), so threading flattens rather
  # than breaking the chain.
  before_validation :siblingize_if_over_max_depth
  before_save       :cache_depth

  scope :top_level, -> { where(parent_id: nil) }
  scope :ordered_for_display, -> { order(:created_at) }

  scope :visible_to, ->(user) {
    joins(:note).merge(Note.visible_to(user))
  }

  private

  def siblingize_if_over_max_depth
    while parent && (parent.depth || 0) >= MAX_DEPTH
      self.parent = parent.parent
    end
  end

  def cache_depth
    self.depth = parent ? [ (parent.depth || 0) + 1, MAX_DEPTH ].min : 0
  end

  def parent_is_not_self
    return if parent_id.nil?

    errors.add(:parent_id, "can't be the comment itself") if parent_id == id
  end
end
