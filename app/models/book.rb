class Book < ApplicationRecord
  belongs_to :translation

  # `scopes: false` avoids clashing with ActiveRecord's Book.new constructor.
  enum :testament, { old: 0, new: 1 }, scopes: false

  validates :osis_code, presence: true, uniqueness: { scope: :translation_id }
  validates :name_en, presence: true
  validates :name_es, presence: true
  validates :position, presence: true, uniqueness: { scope: :translation_id }
  validates :testament, presence: true

  scope :ordered, -> { order(:position) }
end
