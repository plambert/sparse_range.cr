# Additional utility methods for `Range` instances.
#
# WARNING: requiring `sparse_range` reopens the stdlib `Range` struct, so every
# method defined here becomes available on *every* `Range` in the program, not
# just the ones held by a `SparseRange`. Nothing here overrides an existing
# stdlib method, and `Range` is deliberately *not* made `Comparable`: `#<=>` is
# provided as a plain method so that `<`, `<=`, `>`, `>=` and `Comparable#clamp`
# keep their stdlib behaviour (which is to say, they stay undefined).
struct Range(B, E)
  # Returns `true` if this range contains no values at all, either because it is
  # reversed (`10..5`) or because it is exclusive and degenerate (`5...5`).
  #
  # Always `false` for a range with an open end, which is unbounded and so
  # cannot be empty.
  #
  # ```
  # (1..5).no_values?  # => false
  # (10..5).no_values? # => true
  # (5...5).no_values? # => true
  # ```
  def no_values? : Bool
    range_begin = self.begin
    range_end = self.end
    return false if range_begin.nil? || range_end.nil?
    exclusive? ? range_begin >= range_end : range_begin > range_end
  end

  # Returns `true` if this range and *other* share at least one value.
  #
  # Raises `ArgumentError` if either range is exclusive; normalise `a...b` to
  # `a..b.pred` first. An empty range (see `#no_values?`) overlaps nothing.
  #
  # ```
  # (1..5).overlaps? 4..8 # => true
  # (1..5).overlaps? 6..8 # => false
  # ```
  def overlaps?(other) : Bool
    raise ArgumentError.new "cannot check overlap of exclusive ranges" if exclusive? || other.exclusive?
    return false if no_values? || other.no_values?

    # Two ranges overlap exactly when each one begins at or before the other
    # ends. An open bound is infinite in its direction, so it always satisfies
    # the comparison it takes part in.
    begins_by_end_of?(other) && other.begins_by_end_of?(self)
  end

  # Returns `true` if this range begins at or before *other* ends.
  protected def begins_by_end_of?(other) : Bool
    mine = self.begin
    theirs = other.end
    return true if mine.nil? || theirs.nil?
    mine <= theirs
  end

  # Returns `true` if this range ends exactly one value below where *other*
  # begins, or begins exactly one value above where *other* ends. Requires that
  # the bound types respond to `#succ` and `#pred`.
  #
  # Raises `ArgumentError` if either range is exclusive. Never raises
  # `OverflowError`: the successor and predecessor are only computed where they
  # provably cannot wrap.
  #
  # ```
  # (1..5).abuts? 6..8 # => true
  # (6..8).abuts? 1..5 # => true
  # (1..5).abuts? 7..8 # => false
  # ```
  def abuts?(other) : Bool
    raise ArgumentError.new "cannot check abut of exclusive ranges" if exclusive? || other.exclusive?
    return false if no_values? || other.no_values?

    follows_immediately?(other) || other.follows_immediately?(self)
  end

  # Returns `true` if this range begins exactly one value after *other* ends.
  protected def follows_immediately?(other) : Bool
    mine = self.begin
    theirs = other.end
    return false if mine.nil? || theirs.nil?
    # `theirs < mine` keeps `theirs` below the maximum, so `#succ` cannot
    # overflow.
    theirs < mine && theirs.succ == mine
  end

  # Returns `true` if *other* either overlaps or abuts this range.
  def overlaps_or_abuts?(other) : Bool
    overlaps?(other) || abuts?(other)
  end

  # Returns the union of this range and *other* if they overlap or abut,
  # otherwise `nil`. The result is always inclusive.
  #
  # ```
  # (1..5).merge? 4..8   # => 1..8
  # (1..5).merge? 10..12 # => nil
  # ```
  def merge?(other : Range(B, E)) : self?
    return unless overlaps_or_abuts? other
    Range(B, E).new Math.min(self.begin, other.begin), Math.max(self.end, other.end)
  end

  # Returns the union of this range and *other* if they overlap or abut,
  # otherwise returns this range unchanged.
  def merge(other : Range(B, E)) : self
    merge?(other) || self
  end

  # Returns the union of this range and *other*, raising `ArgumentError` if they
  # neither overlap nor abut.
  def merge!(other : Range(B, E)) : self
    merge?(other) ||
      raise ArgumentError.new "cannot merge #{self} with #{other}: they do not overlap or abut"
  end

  # Orders ranges by `#begin`, then by `#end`, then by `#exclusive?`.
  #
  # An open begin sorts first and an open end sorts last, both being unbounded
  # in that direction. For an equal pair of bounds the exclusive range sorts
  # first, since it covers one value fewer.
  #
  # `Range` is deliberately not `Comparable`, so this does not define `<`, `>`,
  # `<=` or `>=`. Use it explicitly: `ranges.sort { |a, b| a <=> b }`.
  def <=>(other : Range(B, E)) : Int32
    result = compare_bounds self.begin, other.begin, nil_sorts_first: true
    return result unless result.zero?
    result = compare_bounds self.end, other.end, nil_sorts_first: false
    return result unless result.zero?
    exclusive_order <=> other.exclusive_order
  end

  protected def exclusive_order : Int32
    exclusive? ? 0 : 1
  end

  private def compare_bounds(mine, theirs, nil_sorts_first : Bool) : Int32
    if mine.nil? && theirs.nil?
      0
    elsif mine.nil?
      nil_sorts_first ? -1 : 1
    elsif theirs.nil?
      nil_sorts_first ? 1 : -1
    else
      (mine <=> theirs) || 0
    end
  end
end
