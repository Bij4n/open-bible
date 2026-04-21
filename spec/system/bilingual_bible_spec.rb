require "rails_helper"

RSpec.describe "Bilingual bible (KJV + RV1909)", type: :system do
  let!(:kjv)    { create(:translation, :kjv) }
  let!(:rv1909) { create(:translation, code: "RV1909", name: "Reina-Valera 1909", language: "es") }

  let!(:kjv_gen) { create(:book, translation: kjv, osis_code: "Gen", name_en: "Genesis", name_es: "Génesis", position: 1, testament: :old) }
  let!(:rv_gen)  { create(:book, translation: rv1909, osis_code: "Gen", name_en: "Genesis", name_es: "Génesis", position: 1, testament: :old) }
  let!(:kjv_gen_1) { create(:chapter, book: kjv_gen, number: 1) }
  let!(:rv_gen_1)  { create(:chapter, book: rv_gen, number: 1) }

  let!(:kjv_john) { create(:book, :john, translation: kjv) }
  let!(:rv_john)  { create(:book, translation: rv1909, osis_code: "John", name_en: "John", name_es: "Juan", position: 43, testament: :new) }
  let!(:kjv_john3) { create(:chapter, book: kjv_john, number: 3) }
  let!(:rv_john3)  { create(:chapter, book: rv_john, number: 3) }

  let!(:kjv_gen_1_1) do
    create(:verse, chapter: kjv_gen_1, number: 1,
                   body_text: "In the beginning God created the heaven and the earth.",
                   body_html: "In the beginning God created the heaven and the earth.",
                   osis_ref: "Bible.KJV.Gen.1.1")
  end
  let!(:rv_gen_1_1) do
    create(:verse, chapter: rv_gen_1, number: 1,
                   body_text: "EN el principio crió Dios los cielos y la tierra.",
                   body_html: "EN el principio crió Dios los cielos y la tierra.",
                   osis_ref: "Bible.RV1909.Gen.1.1")
  end
  let!(:kjv_john_3_16) do
    create(:verse, chapter: kjv_john3, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   osis_ref: "Bible.KJV.John.3.16")
  end
  let!(:rv_john_3_16) do
    create(:verse, chapter: rv_john3, number: 16,
                   body_text: "Porque de tal manera amó Dios al mundo",
                   body_html: "Porque de tal manera amó Dios al mundo",
                   osis_ref: "Bible.RV1909.John.3.16")
  end

  describe "translation picker" do
    it "shows both translations as options when viewing a chapter" do
      sign_in create(:user)
      visit "/bible/kjv/john/3"

      expect(page).to have_content("For God so loved")
      expect(page).to have_select(nil, selected: "King James Version",
                                  options: [ "King James Version", "Reina-Valera 1909" ])
      # Option values are preloaded URLs — visiting the RV1909 option
      # lands on the same book and chapter in the other translation.
      expect(page).to have_css(%(option[value="/bible/rv1909/john/3"]))
    end

    it "preserves the chapter when following the picker's RV1909 option url" do
      sign_in create(:user)
      visit "/bible/kjv/john/3"
      visit "/bible/rv1909/john/3"

      expect(page).to have_content("Porque de tal manera amó")
      expect(page).to have_content("Reina-Valera 1909")
    end
  end

  describe "Spanish locale display" do
    it "renders the book heading as 'Juan' for es users on the RV1909 reader" do
      user = create(:user, ui_locale: "es")
      sign_in user
      visit "/bible/rv1909/john/3"

      expect(page).to have_css("h1", text: /Juan 3/i)
      # URL stays OSIS-keyed regardless of locale.
      expect(page.current_path).to eq("/bible/rv1909/john/3")
    end

    it "renders 'John' for en users on the same RV1909 reader" do
      user = create(:user, ui_locale: "en")
      sign_in user
      visit "/bible/rv1909/john/3"

      expect(page).to have_css("h1", text: /John 3/i)
    end
  end

  describe "default translation on /bible entry" do
    it "honors the user's default_translation on first /bible visit" do
      user = create(:user, default_translation: rv1909)
      sign_in user
      visit "/bible"

      expect(page.current_path).to eq("/bible/rv1909/gen/1")
      expect(page).to have_content("crió Dios")
    end

    it "falls back to KJV Genesis 1 when no default is set" do
      sign_in create(:user)
      visit "/bible"

      expect(page.current_path).to eq("/bible/kjv/gen/1")
      expect(page).to have_content("In the beginning")
    end
  end

  describe "cross-translation search" do
    # pg_search matches by lexeme so an English query like "love" won't
    # hit Spanish text — each language is scoped separately. The useful
    # assertion for translations=all is "a Spanish query reaches the
    # Spanish translation's verses", which proves the scope opened up.

    it "reaches RV1909 verses when translations=all (Spanish query)" do
      visit "/search?q=mundo&translations=all"

      # "mundo" appears only in the RV1909 verse.
      expect(page).to have_content("Porque de tal manera")
    end

    it "still reaches KJV when translations=all (English query)" do
      visit "/search?q=love&translations=all"

      expect(page).to have_content("John 3:16")
      expect(page).to have_content("For God so")
    end

    it "defaults to current-translation scoping (KJV) and excludes RV1909" do
      visit "/search?q=mundo"

      # Query hits only RV1909, but default scope is KJV-only, so no
      # results surface.
      expect(page).not_to have_content("Porque de tal manera")
    end
  end

  describe "cross-translation highlight badge" do
    it "shows the bridge badge when viewing a verse highlighted in another translation" do
      user = create(:user)
      user.highlights.create!(translation: kjv,
                              osis_ref: "Bible.KJV.John.3.16",
                              color: "gold")
      sign_in user
      visit "/bible/rv1909/john/3"

      expect(page).to have_css(".cross-translation-badge")
    end

    it "clicks the bridge badge to jump back to the other translation's reader" do
      user = create(:user)
      user.highlights.create!(translation: kjv,
                              osis_ref: "Bible.KJV.John.3.16",
                              color: "gold")
      sign_in user

      visit "/bible/rv1909/john/3"
      expect(page).to have_content("Porque de tal manera amó")

      find(".cross-translation-badge").click

      expect(page.current_path).to eq("/bible/kjv/john/3")
      expect(page).to have_content("For God so loved")
    end
  end
end
