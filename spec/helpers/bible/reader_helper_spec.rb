require "rails_helper"

RSpec.describe Bible::ReaderHelper, type: :helper do
  let(:translation) { create(:translation, :kjv) }
  let(:book)        { create(:book, :john, translation: translation) }
  let(:chapter)     { create(:chapter, book: book, number: 3) }

  def make_verse(number, body, red_ranges = [])
    create(:verse,
           chapter: chapter,
           number: number,
           body_text: body,
           body_html: body,  # helper doesn't read body_html — it re-renders
           red_letter_ranges: red_ranges,
           osis_ref: "Bible.KJV.John.3.#{number}")
  end

  def highlight_for(user, osis_ref, color = "gold")
    create(:highlight, user: user, translation: translation, osis_ref: osis_ref, color: color)
  end

  let(:user) { create(:user) }

  describe "#render_verse_with_highlights" do
    it "returns plain escaped text when there are no highlights or red letters" do
      verse = make_verse(1, "In the beginning")
      html = helper.render_verse_with_highlights(verse, [])
      expect(html).to eq("In the beginning")
    end

    it "renders a bare verse ref as a full-verse highlight" do
      verse = make_verse(1, "Hello world")
      highlight = highlight_for(user, "Bible.KJV.John.3.1")
      html = helper.render_verse_with_highlights(verse, [ highlight ])
      expect(html).to eq(%(<span class="highlight-gold" data-highlight-ids="#{highlight.id}">Hello world</span>))
    end

    it "renders a character range within a single verse" do
      verse = make_verse(1, "Hello world")
      highlight = highlight_for(user, "Bible.KJV.John.3.1!6-Bible.KJV.John.3.1!11")
      html = helper.render_verse_with_highlights(verse, [ highlight ])
      expect(html).to eq(%(Hello <span class="highlight-gold" data-highlight-ids="#{highlight.id}">world</span>))
    end

    it "extends a cross-verse highlight to the end when this verse is the start" do
      verse = make_verse(1, "Hello world")
      highlight = highlight_for(user, "Bible.KJV.John.3.1!6-Bible.KJV.John.3.2!3")
      html = helper.render_verse_with_highlights(verse, [ highlight ])
      expect(html).to eq(%(Hello <span class="highlight-gold" data-highlight-ids="#{highlight.id}">world</span>))
    end

    it "starts a cross-verse highlight at 0 when this verse is the end" do
      v1 = make_verse(1, "Hello world")
      _v2 = nil
      verse = make_verse(2, "Another verse")
      highlight = highlight_for(user, "Bible.KJV.John.3.1!6-Bible.KJV.John.3.2!7")
      html = helper.render_verse_with_highlights(verse, [ highlight ])
      expect(html).to eq(%(<span class="highlight-gold" data-highlight-ids="#{highlight.id}">Another</span> verse))
    end

    it "preserves Jesus-words when a highlight overlaps them" do
      # body: "He said: Love God" — "Love God" is red (offsets 9..17)
      verse = make_verse(1, "He said: Love God", [ [ 9, 17 ] ])
      # Highlight covers "said: Love" (offsets 3..14)
      highlight = highlight_for(user, "Bible.KJV.John.3.1!3-Bible.KJV.John.3.1!14")
      html = helper.render_verse_with_highlights(verse, [ highlight ])
      # Fragments:
      #   [0,3)  "He "       plain
      #   [3,9)  "said: "    highlight only
      #   [9,14) "Love "     jesus + highlight (overlap region)
      #   [14,17)"God"       jesus only
      expect(html).to include("He ")
      expect(html).to include(%(<span class="highlight-gold" data-highlight-ids="#{highlight.id}">said: </span>))
      expect(html).to include(%(<span class="jesus-words highlight-gold" data-highlight-ids="#{highlight.id}">Love </span>))
      expect(html).to include(%(<span class="jesus-words">God</span>))
    end

    it "renders Jesus-words with no highlight as a plain red-letter span" do
      verse = make_verse(1, "Go in peace", [ [ 0, 11 ] ])
      html = helper.render_verse_with_highlights(verse, [])
      expect(html).to eq(%(<span class="jesus-words">Go in peace</span>))
    end

    it "picks the highest-id highlight's color for overlapping regions and lists both ids" do
      verse = make_verse(1, "Hello world")
      h1 = highlight_for(user, "Bible.KJV.John.3.1!0-Bible.KJV.John.3.1!8", "gold")
      h2 = highlight_for(user, "Bible.KJV.John.3.1!5-Bible.KJV.John.3.1!11", "sage")
      html = helper.render_verse_with_highlights(verse, [ h1, h2 ])
      # Positions:
      # [0..5) "Hello" → h1 only (gold)
      # [5..8) "lo " wait... "Hello world" offsets: H=0, e=1, l=2, l=3, o=4, ' '=5, w=6, o=7, r=8, l=9, d=10
      # h1 covers [0, 8) = "Hello wo"
      # h2 covers [5, 11) = " world"
      # overlap [5, 8) = " wo" → both active, h2 (higher id) wins color
      # [0..5) h1 only → gold
      # [5..8) both → sage (h2 later), data-highlight-ids="h1,h2"
      # [8..11) h2 only → sage
      expect(html).to include(%(<span class="highlight-gold" data-highlight-ids="#{h1.id}">Hello</span>))
      expect(html).to include(%(<span class="highlight-sage" data-highlight-ids="#{h1.id},#{h2.id}"> wo</span>))
      expect(html).to include(%(<span class="highlight-sage" data-highlight-ids="#{h2.id}">rld</span>))
    end

    it "handles highlights at exact verse boundaries" do
      verse = make_verse(1, "abc")
      highlight = highlight_for(user, "Bible.KJV.John.3.1!0-Bible.KJV.John.3.1!end")
      html = helper.render_verse_with_highlights(verse, [ highlight ])
      expect(html).to eq(%(<span class="highlight-gold" data-highlight-ids="#{highlight.id}">abc</span>))
    end

    it "escapes HTML in verse text" do
      verse = make_verse(1, "a <b> c")
      html = helper.render_verse_with_highlights(verse, [])
      expect(html).to eq("a &lt;b&gt; c")
    end
  end
end
