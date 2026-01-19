class Translation < ApplicationRecord
  has_many :books, dependent: :destroy

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :language, presence: true
end
