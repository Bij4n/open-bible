# Note-rendering helpers shared across the reader panels, lists, and
# community cards.
module NotesHelper
  # Tiny inline glyph echoing a note's visibility everywhere it renders
  # (design v3 §4.2): lock = only me, two people = friends, one person =
  # specific people, book = study, globe = public. Title for sighted
  # hover, sr-only text for screen readers.
  VISIBILITY_GLYPH_PATHS = {
    "private_note"  => "M12 1.5a4.5 4.5 0 0 0-4.5 4.5v3h-.75A2.25 2.25 0 0 0 4.5 11.25v8.25A2.25 2.25 0 0 0 6.75 21.75h10.5A2.25 2.25 0 0 0 19.5 19.5v-8.25A2.25 2.25 0 0 0 17.25 9h-.75V6A4.5 4.5 0 0 0 12 1.5Zm3 7.5V6a3 3 0 1 0-6 0v3h6Z",
    "friends_note"  => "M8.25 6.75a3.75 3.75 0 1 1 7.5 0 3.75 3.75 0 0 1-7.5 0ZM15.75 9.75a3 3 0 1 1 6 0 3 3 0 0 1-6 0ZM2.25 9.75a3 3 0 1 1 6 0 3 3 0 0 1-6 0ZM6.31 15.117A6.745 6.745 0 0 1 12 12a6.745 6.745 0 0 1 6.709 7.498.75.75 0 0 1-.372.568A12.696 12.696 0 0 1 12 21.75c-2.305 0-4.47-.612-6.337-1.684a.75.75 0 0 1-.372-.568 6.787 6.787 0 0 1 1.019-4.38Z",
    "shared_users"  => "M7.5 6a4.5 4.5 0 1 1 9 0 4.5 4.5 0 0 1-9 0ZM3.751 20.105a8.25 8.25 0 0 1 16.498 0 .75.75 0 0 1-.437.695A18.683 18.683 0 0 1 12 22.5c-2.786 0-5.433-.608-7.812-1.7a.75.75 0 0 1-.437-.695Z",
    "shared_groups" => "M11.25 4.533A9.707 9.707 0 0 0 6 3a9.735 9.735 0 0 0-3.25.555.75.75 0 0 0-.5.707v14.25a.75.75 0 0 0 1 .707A8.237 8.237 0 0 1 6 18.75c1.995 0 3.823.707 5.25 1.886V4.533ZM12.75 20.636A8.214 8.214 0 0 1 18 18.75c.966 0 1.89.166 2.75.47a.75.75 0 0 0 1-.708V4.262a.75.75 0 0 0-.5-.707A9.735 9.735 0 0 0 18 3a9.707 9.707 0 0 0-5.25 1.533v16.103Z",
    "public_note"   => "M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25ZM6.262 6.072A8.25 8.25 0 1 0 10.5 3.889c-.076.817.011 1.654.34 2.31.402.802 1.16 1.3 2.16 1.3.6 0 1.137.244 1.526.642.396.405.643.964.643 1.609 0 .646-.247 1.204-.643 1.609a2.12 2.12 0 0 1-1.526.642c-1.218 0-2.16.985-2.16 2.25v.443c0 .68-.557 1.231-1.24 1.231-.683 0-1.24-.551-1.24-1.231v-.443c0-1.265-.942-2.25-2.16-2.25-.6 0-1.137-.244-1.526-.642a2.27 2.27 0 0 1-.612-1.287Z"
  }.freeze

  def visibility_glyph(note)
    label = t("notes.visibility.#{note.visibility}")
    path  = VISIBILITY_GLYPH_PATHS.fetch(note.visibility)

    tag.span(title: label, class: "inline-flex items-center align-middle text-surface-400 dark:text-surface-500") do
      svg = <<~SVG.html_safe
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="h-3.5 w-3.5" aria-hidden="true"><path fill-rule="evenodd" d="#{path}" clip-rule="evenodd"/></svg>
      SVG
      svg + tag.span(label, class: "sr-only")
    end
  end
end
