class HomeController < ApplicationController
  # Sprint 19+ Category A.1: hero verse card. When an admin features a
  # public note (via /admin/notes feature action), the most-recently-
  # featured one surfaces in the homepage hero as a verse-card spotlight.
  # Renders nothing in the hero card slot when no featured public note
  # exists — the hero gracefully degrades to single-column text-only.
  COMMUNITY_NOTE_LIMIT = 3

  def show
    @hero_note = featured_hero_note
    @hero_verse = @hero_note ? hero_verse_for(@hero_note) : nil
    @community_entries = community_entries(skip_id: @hero_note&.id)
  end

  private

  # Sprint 22.3 — community section. Returns up to COMMUNITY_NOTE_LIMIT
  # tuples of [note, verse], skipping the featured hero note (so we
  # don't double-show it). Each tuple's verse is the first verse the
  # note's first highlight covers — same shape as the hero card. Notes
  # without a resolvable verse (orphaned highlights, parse errors) are
  # silently dropped from the list.
  def community_entries(skip_id:)
    scope = Note.public_visible
                .includes(:user, :highlights)
                .order(created_at: :desc)
    scope = scope.where.not(id: skip_id) if skip_id
    scope.limit(COMMUNITY_NOTE_LIMIT * 2).filter_map do |note|
      verse = hero_verse_for(note)
      verse && [ note, verse ]
    end.take(COMMUNITY_NOTE_LIMIT)
  end

  def featured_hero_note
    Note.public_visible
        .featured
        .includes(:user, :highlights)
        .order(featured_at: :desc)
        .first
  end

  # The verse to render in the hero card — first verse covered by the
  # note's first highlight. Returns nil if the note has no highlights
  # or the verse can't be resolved (defensive against orphaned data).
  def hero_verse_for(note)
    highlight = note.highlights.first
    return nil unless highlight

    parsed = OsisRef.parse(highlight.osis_ref, strict: :same_chapter)
    Verse.where(osis_ref: parsed.verse_osis_refs)
         .includes(chapter: { book: :translation })
         .first
  rescue OsisRef::ParseError
    nil
  end
end
