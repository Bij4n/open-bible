# Canonical reference parser/builder for Bible locations. Format:
#
#   Bible.<translation>.<book>.<chapter>.<verse>[!<offset>]
#     (optionally followed by "-" + a second endpoint)
#
# where <offset> is an integer character offset into the verse's plain
# text (`body_text`) or the sentinel `end` meaning "end of verse".
#
# Sprint 3 highlights are enforced to the same-chapter subset via
# `strict: :same_chapter`; multi-chapter refs still parse so future
# features (shared notes, search) can operate on them.
class OsisRef
  class ParseError < StandardError; end
  class ScopeError < ParseError; end
  class MultiChapterNotSupported < StandardError; end

  END_OFFSET = :end

  ENDPOINT_RE = /
    \ABible\.
    (?<translation>[A-Z][A-Z0-9_]*)\.
    (?<book>[A-Za-z0-9]+)\.
    (?<chapter>\d+)\.
    (?<verse>\d+)
    (?:!(?<offset>\d+|end))?
    \z
  /x

  attr_reader :translation_code,
              :start_book, :start_chapter, :start_verse, :start_offset,
              :end_book,   :end_chapter,   :end_verse,   :end_offset

  def self.parse(input, strict: nil)
    raise ParseError, "empty input" if input.nil? || input.to_s.strip.empty?

    str = input.to_s.strip
    left, right = split_endpoints(str)
    start_ep = parse_endpoint(left)
    end_ep   = right ? parse_endpoint(right) : start_ep

    unless start_ep[:translation] == end_ep[:translation]
      raise ParseError, "translation mismatch between endpoints"
    end

    ref = new(
      translation_code: start_ep[:translation],
      start_book:       start_ep[:book],
      start_chapter:    start_ep[:chapter],
      start_verse:      start_ep[:verse],
      start_offset:     start_ep[:offset],
      end_book:         end_ep[:book],
      end_chapter:      end_ep[:chapter],
      end_verse:        end_ep[:verse],
      end_offset:       end_ep[:offset]
    )
    validate_ordering!(ref)
    enforce_scope!(ref, strict)
    ref
  end

  def self.build(translation_code:, start:, end: nil)
    start_parts = start
    end_parts   = binding.local_variable_get(:end) || start_parts
    new(
      translation_code: translation_code,
      start_book:       start_parts[:book],
      start_chapter:    start_parts[:chapter],
      start_verse:      start_parts[:verse],
      start_offset:     start_parts[:offset],
      end_book:         end_parts[:book],
      end_chapter:      end_parts[:chapter],
      end_verse:        end_parts[:verse],
      end_offset:       end_parts[:offset]
    )
  end

  def initialize(translation_code:, start_book:, start_chapter:, start_verse:, start_offset:,
                 end_book:, end_chapter:, end_verse:, end_offset:)
    @translation_code = translation_code
    @start_book       = start_book
    @start_chapter    = start_chapter
    @start_verse      = start_verse
    @start_offset     = start_offset
    @end_book         = end_book
    @end_chapter      = end_chapter
    @end_verse        = end_verse
    @end_offset       = end_offset
  end

  def single_verse?
    bare_endpoint?(start_offset) && bare_endpoint?(end_offset) &&
      start_book == end_book && start_chapter == end_chapter && start_verse == end_verse
  end

  def cross_verse?
    start_book != end_book || start_chapter != end_chapter || start_verse != end_verse
  end

  def same_chapter?
    start_book == end_book && start_chapter == end_chapter
  end

  # Every bare-verse OsisRef string the ref touches, for things like
  # prefix queries or UI citations. Raises on cross-chapter refs because
  # we can't enumerate the last chapter's verse count without the DB.
  def verse_osis_refs
    raise MultiChapterNotSupported unless same_chapter?

    (start_verse..end_verse).map do |v|
      "Bible.#{translation_code}.#{start_book}.#{start_chapter}.#{v}"
    end
  end

  def to_s
    left  = endpoint_s(start_book, start_chapter, start_verse, start_offset)
    right = endpoint_s(end_book,   end_chapter,   end_verse,   end_offset)
    left == right ? left : "#{left}-#{right}"
  end

  def ==(other)
    other.is_a?(OsisRef) && to_s == other.to_s
  end

  alias eql? ==

  def hash
    to_s.hash
  end

  def self.split_endpoints(str)
    return [ str, nil ] unless str.include?("-")

    # Split on the first "-" that sits between two Bible.* endpoints.
    idx = str.index("-Bible.")
    raise ParseError, "expected '-Bible.' between endpoints" unless idx

    [ str[0...idx], str[(idx + 1)..] ]
  end
  private_class_method :split_endpoints

  def self.parse_endpoint(str)
    md = ENDPOINT_RE.match(str)
    raise ParseError, "malformed endpoint: #{str.inspect}" unless md

    offset = md[:offset]
    parsed_offset =
      case offset
      when nil       then nil
      when "end"     then END_OFFSET
      else                offset.to_i
      end

    {
      translation: md[:translation],
      book:        md[:book],
      chapter:     md[:chapter].to_i,
      verse:       md[:verse].to_i,
      offset:      parsed_offset
    }
  end
  private_class_method :parse_endpoint

  def self.validate_ordering!(ref)
    # Book ordering isn't lexicographic (1Kgs comes after 2Sam in canon),
    # and we lack the ordering table here. Accept different books without
    # a backwards check; downstream code that cares (strict, highlight
    # renderer) uses other constraints.
    return if ref.start_book != ref.end_book

    if ref.start_chapter > ref.end_chapter
      raise ParseError, "backwards ref (start chapter after end chapter)"
    end
    return if ref.start_chapter < ref.end_chapter

    if ref.start_verse > ref.end_verse
      raise ParseError, "backwards ref (start verse after end verse)"
    end
    return if ref.start_verse < ref.end_verse

    return if offset_le?(ref.start_offset, ref.end_offset)

    raise ParseError, "backwards ref (start offset after end offset in same verse)"
  end
  private_class_method :validate_ordering!

  # :end is always >= any integer offset in the same verse.
  def self.offset_le?(a, b)
    return true  if a.nil? && b.nil?
    return true  if b == END_OFFSET
    return false if a == END_OFFSET

    a.to_i <= b.to_i
  end
  private_class_method :offset_le?

  def self.enforce_scope!(ref, strict)
    case strict
    when nil
      nil
    when :same_chapter
      raise ScopeError, "ref spans multiple chapters" unless ref.same_chapter?
    else
      raise ArgumentError, "unknown strict mode: #{strict.inspect}"
    end
  end
  private_class_method :enforce_scope!

  private

  def bare_endpoint?(offset)
    offset.nil?
  end

  def endpoint_s(book, chapter, verse, offset)
    base = "Bible.#{translation_code}.#{book}.#{chapter}.#{verse}"
    return base if offset.nil?

    "#{base}!#{offset == END_OFFSET ? "end" : offset}"
  end
end
