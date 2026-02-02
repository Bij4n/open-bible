class NoteShare < ApplicationRecord
  belongs_to :note
  belongs_to :shareable, polymorphic: true

  validates :shareable_type, inclusion: { in: %w[User Group] }
  validates :note_id, uniqueness: { scope: [ :shareable_type, :shareable_id ] }
end
