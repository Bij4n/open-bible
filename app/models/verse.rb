class Verse < ApplicationRecord
  include PgSearch::Model

  belongs_to :chapter

  validates :number, presence: true, uniqueness: { scope: :chapter_id }
  validates :body_text, presence: true
  validates :osis_ref, presence: true, uniqueness: true

  # Keyword search over verse text. Prefix matches so "lov" hits "loved";
  # ts_headline wraps matched terms in <mark> so the view can render the
  # highlighted fragment directly. body_text is plain text, so the
  # highlighted output is safe to html_safe.
  pg_search_scope :search_text,
                  against: :body_text,
                  using: {
                    tsearch: {
                      prefix: true,
                      highlight: {
                        StartSel: "<mark>",
                        StopSel:  "</mark>"
                      }
                    }
                  }
end
