require "bit_array"
require "string_scanner"
require "json"

require "./constructors"
require "./range_util"

# A `SparseRange` manages a non-contiguous set of integer values as a sorted
# list of `Range(T, T)`.
#
# ```
# sparserange = SparseRange(Int32).new
# sparserange.add 21
# sparserange.add 1234..1243
# sparserange.size  # => 2       distinct ranges
# sparserange.count # => 11      distinct values
# sparserange.span  # => 1223    max - min + 1
# ```
#
# Overlapping and adjacent ranges are always coalesced, so the stored list is
# the shortest one that represents the set:
#
# ```
# sparserange = SparseRange(Int32).new([1..3, 5..10])
# sparserange.add 4
# sparserange.size   # => 1
# sparserange.ranges # => [1..10]
# ```
#
# `T` must respond to `#succ`, `#pred`, `::MIN` and `::MAX`; in practice that
# means one of the integer types. Values are never assumed to fit in any
# particular width: `#count` and `#span` return `UInt128` so that they stay
# correct across the full range of `T`.
class SparseRange(T)
  # Raised when a string cannot be parsed into a `SparseRange`.
  class ParseException < Exception; end

  # Raised by `#assert!` when the range list violates the class invariant.
  class AssertionError < Exception; end

  {% begin %}
    # The shard version, read from `shard.yml` at build time.
    VERSION = {{ `shards version`.strip.stringify }}
  {% end %}

  # :nodoc:
  REGEX_INT = /[-+]?\d+/
  # :nodoc:
  REGEX_RANGE = /(#{REGEX_INT})\s*\.\.\s*(#{REGEX_INT})/
  # :nodoc:
  REGEX_RANGEX = /(#{REGEX_INT})\s*\.\.\.\s*(#{REGEX_INT})/

  # The stored ranges, always sorted by `#begin`, non-overlapping and
  # non-adjacent. Treat the returned array as read-only; mutating it bypasses
  # every invariant this class maintains.
  getter ranges : Array(Range(T, T))

  # The memoized result of `#count!`, cleared by `#dirty!`.
  getter cached_count : UInt128? = nil

  # When true, every mutation traces its progress to `STDERR`.
  property? debug : Bool = false

  # Creates an empty `SparseRange`.
  def initialize(@debug : Bool = ENV["SPARSE_RANGE_DEBUG"]? ? true : false)
    check_type
    @ranges = [] of Range(T, T)
    trace "initialize()"
  end

  # Creates a `SparseRange` from an existing array of ranges.
  #
  # The array is copied. By default the result is validated with `#assert!`;
  # pass `assert: false` to sort and coalesce it instead, or `assert: false,
  # sort: false` to take it verbatim.
  def initialize(*, ranges : Array(Range(T, T)), assert : Bool = true, sort : Bool? = nil,
                 @debug : Bool = ENV["SPARSE_RANGE_DEBUG"]? ? true : false)
    check_type
    @ranges = ranges.dup
    trace "initialize(ranges: #{@ranges.inspect})"
    if assert
      assert!
    elsif sort != false
      sort!
    end
  end

  # Creates a `SparseRange` from a list of values, ranges, or arrays of either.
  def initialize(list : Array(Range(T, T) | Array(Range(T, T)) | T), assert : Bool = true,
                 sort : Bool? = nil,
                 @debug : Bool = ENV["SPARSE_RANGE_DEBUG"]? ? true : false)
    check_type
    @ranges = [] of Range(T, T)
    trace "initialize(list: #{list.inspect})"
    list.each do |entry|
      case entry
      in Range(T, T)
        append_normalized entry
      in Array(Range(T, T))
        entry.each { |range| append_normalized range }
      in T
        @ranges << Range(T, T).new(entry, entry)
      end
    end
    if assert
      assert!
    elsif sort != false
      sort!
    end
  end

  # Creates a `SparseRange` by parsing *list*, a comma-separated list of
  # integers and ranges, optionally wrapped in square brackets.
  #
  # ```
  # SparseRange(Int32).new(list: "1..10,30,99..101").ranges # => [1..10, 30..30, 99..101]
  # SparseRange(Int32).new(list: "[1...5, 7]").ranges       # => [1..4, 7..7]
  # ```
  #
  # Raises `ParseException` if *list* is not a well-formed list, or if a value
  # does not fit in `T`. The result is sorted and coalesced.
  def initialize(*, list : String, @debug : Bool = ENV["SPARSE_RANGE_DEBUG"]? ? true : false)
    check_type
    @ranges = [] of Range(T, T)
    trace "initialize(list: #{list.inspect})"
    parse list
    sort!
  end

  # Removes every value, leaving an empty `SparseRange`.
  def clear : self
    @ranges.clear
    dirty!
    self
  end

  # Returns a new `SparseRange` holding every value of `T` that this one does
  # not.
  #
  # ```
  # SparseRange(Int8).new([0_i8..3_i8]).invert.ranges # => [-128..-1, 4..127]
  # ```
  def invert : self
    result = self.class.new ranges: [Range(T, T).new(T::MIN, T::MAX)], assert: false, sort: false
    each_range { |range| result.subtract range }
    result
  end

  # Replaces the contents of this `SparseRange` with its complement.
  def invert! : self
    @ranges = invert.ranges
    dirty!
    self
  end

  # Returns an `Iterator` over every value in the set, in ascending order.
  def each : Iterator(T)
    Iterator.chain(@ranges.map(&.each))
  end

  # Yields every value in the set, in ascending order.
  def each(& : T ->) : Nil
    @ranges.each do |range|
      range.each { |value| yield value }
    end
  end

  # Returns an `Iterator` over the stored ranges.
  def each_range : Iterator(Range(T, T))
    @ranges.each
  end

  # Yields each stored range, in ascending order.
  def each_range(& : Range(T, T) ->) : Nil
    @ranges.each { |range| yield range }
  end

  # Yields every value between *start_at* and *end_at* inclusive that is *not*
  # in the set. Defaults to the gaps between `#min` and `#max`.
  #
  # ```
  # SparseRange(Int32).new(list: "10..12,20..22").each_excluded(0, 15) { |v| print v, ' ' }
  # # prints: 0 1 2 3 4 5 6 7 8 9 13 14 15
  # ```
  def each_excluded(start_at : T? = min?, end_at : T? = max?, & : T ->) : Nil
    return if start_at.nil? || end_at.nil? || start_at > end_at
    pointer = start_at
    @ranges.each do |range|
      next if range.end < pointer
      break if range.begin > end_at
      if pointer < range.begin
        (pointer..Math.min(range.begin.pred, end_at)).each { |value| yield value }
      end
      # `range.end < end_at <= T::MAX` here, so `#succ` cannot overflow.
      return if range.end >= end_at
      pointer = range.end.succ
    end
    (pointer..end_at).each { |value| yield value } if pointer <= end_at
  end

  # Returns `true` if the set holds no values.
  def empty? : Bool
    @ranges.empty?
  end

  # Returns the smallest value in the set, or `nil` if it is empty.
  def min? : T?
    @ranges.first?.try &.begin
  end

  # Returns the smallest value in the set. Raises `IndexError` if it is empty.
  def min : T
    min? || raise IndexError.new "empty #{self.class} has no min"
  end

  # Returns the largest value in the set, or `nil` if it is empty.
  def max? : T?
    @ranges.last?.try &.end
  end

  # Returns the largest value in the set. Raises `IndexError` if it is empty.
  def max : T
    max? || raise IndexError.new "empty #{self.class} has no max"
  end

  # Returns an independent copy of this `SparseRange`.
  def dup : self
    self.class.new ranges: @ranges, assert: false, sort: false, debug: @debug
  end

  # Defines `#to_<name>?`, converting this `SparseRange` to one over
  # *target_type*, or `nil` if any value falls outside that type.
  macro def_to(method_name, target_type)
    # Returns this set converted to a `SparseRange({{ target_type.id }})`, or
    # `nil` if any value does not fit in `{{ target_type.id }}`.
    def to_{{ method_name.id }}? : SparseRange({{ target_type.id }})?
      return SparseRange({{ target_type.id }}).new if empty?
      return nil if min < {{ target_type.id }}::MIN || max > {{ target_type.id }}::MAX
      converted = @ranges.map do |range|
        Range({{ target_type.id }}, {{ target_type.id }}).new(
          {{ target_type.id }}.new(range.begin),
          {{ target_type.id }}.new(range.end),
        )
      end
      SparseRange({{ target_type.id }}).new ranges: converted, assert: false, sort: false
    end
  end

  # 8-bit conversions are intentionally omitted: at that width a `BitArray` is
  # both denser and faster than a list of ranges.

  def_to(:u128, UInt128)
  def_to(:i128, Int128)
  def_to(:u64, UInt64)
  def_to(:i64, Int64)
  def_to(:u32, UInt32)
  def_to(:i32, Int32)
  def_to(:u16, UInt16)
  def_to(:i16, Int16)

  # Sorts and coalesces the stored ranges, restoring the class invariant.
  #
  # Exclusive ranges are normalised to inclusive ones and empty ranges are
  # dropped.
  def sort! : self
    dirty!
    trace "sort! before: #{@ranges.inspect}"
    @ranges.sort! { |a, b| a.begin <=> b.begin }
    merged = Array(Range(T, T)).new @ranges.size
    @ranges.each do |range|
      range = Range(T, T).new(range.begin, range.end.pred) if range.exclusive? && range.begin < range.end
      next if range.no_values?
      last = merged.last?
      if last && contiguous_with?(last, range)
        merged[-1] = Range(T, T).new(last.begin, Math.max(last.end, range.end))
      else
        merged << Range(T, T).new(range.begin, range.end)
      end
    end
    @ranges = merged
    trace "sort! after: #{@ranges.inspect}"
    self
  end

  # Returns `true` if the stored ranges satisfy the class invariant: each range
  # is inclusive and non-empty, and each is strictly more than one value beyond
  # the end of the one before it.
  def assert? : Bool
    invariant_violation.nil?
  end

  # Raises `AssertionError` unless the stored ranges satisfy the class
  # invariant. See `#assert?`.
  def assert! : self
    if violation = invariant_violation
      raise AssertionError.new violation
    end
    self
  end

  # Returns `true` if at least half of the values between `#min` and `#max` are
  # in the set.
  def crowded? : Bool
    if total = span?
      crowded_within? total
    else
      false
    end
  end

  # Returns `true` if the set holds at least half of *span* values.
  #
  # ```
  # SparseRange(Int32).new(list: "1,2,3").crowded? 9 # => false
  # SparseRange(Int32).new(list: "1,2,3").crowded? 5 # => true
  # ```
  def crowded?(span total : T) : Bool
    return false if total <= T.zero
    crowded_within? self.class.distance(T.zero, total)
  end

  # Returns `true` if at least half of the values between *lower_limit* and
  # *upper_limit* inclusive are in the set.
  def crowded?(lower_limit : T, upper_limit : T) : Bool
    return false if upper_limit < lower_limit
    crowded_within? self.class.distance(lower_limit, upper_limit) + 1
  end

  # Returns `true` if at least half of the values in *range* are in the set.
  def crowded?(range : Range(T, T)) : Bool
    return false if range.no_values?
    range_end = range.exclusive? ? range.end.pred : range.end
    crowded_within? self.class.distance(range.begin, range_end) + 1
  end

  # Returns a `BitArray` with a bit set for every value in the set, indexed from
  # zero.
  #
  # Raises `ArgumentError` if the set holds negative values, or if `#max` is too
  # large to index a `BitArray`.
  def to_bitarray : BitArray
    return BitArray.new(0) if empty?
    min_value = min
    if min_value < T.zero
      raise ArgumentError.new "cannot index a BitArray with negative values (#{min_value}..#{max})"
    end
    max_value = max
    bit_count = self.class.distance(T.zero, max_value) + 1
    if bit_count > Int32::MAX
      raise ArgumentError.new "#{self.class} needs #{bit_count} bits, more than a BitArray can hold"
    end

    # A crowded set is cheaper to describe by its gaps, a sparse one by its
    # values.
    if crowded?
      bitarray = BitArray.new bit_count.to_i32, true
      each_excluded(T.zero, max_value) { |value| bitarray[self.class.offset(value)] = false }
    else
      bitarray = BitArray.new bit_count.to_i32, false
      each { |value| bitarray[self.class.offset(value)] = true }
    end
    bitarray
  end

  # Returns a string of `'0'` and `'1'` characters, one per value from zero to
  # `#max`.
  #
  # ```
  # SparseRange(Int32).new(list: "1,3,5").to_bitstring # => "010101"
  # ```
  def to_bitstring : String
    String.build do |io|
      to_bitstring io
    end
  end

  # Writes this set's bitstring to *io*. See `#to_bitstring`.
  def to_bitstring(io : IO) : Nil
    to_bitarray.each do |bit|
      io << (bit ? '1' : '0')
    end
  end

  # Adds every value in *item* to the set. Equivalent to `#add`.
  def <<(item) : self
    add item
  end

  # Discards the memoized `#count`.
  def dirty! : Nil
    @cached_count = nil
  end

  # Adds every value in each of *items* to the set.
  #
  # Exclusive ranges are normalised to inclusive ones and empty ranges are
  # ignored. Raises `ArgumentError` for a reversed range such as `10..5`.
  def add(*items : T | Range(T, T) | Array(T) | Array(Range(T, T)) | Array(T | Range(T, T))) : self
    items.each do |item|
      case item
      in T
        add_one item
      in Range(T, T)
        add_one item
      in Array
        item.each { |entry| add_one entry }
      end
    end
    self
  end

  # Removes every value in each of *others* from the set.
  def subtract(*others : T | Range(T, T) | Array(T) | Array(Range(T, T)) | Array(T | Range(T, T))) : self
    others.each do |item|
      case item
      in T
        subtract_one item
      in Range(T, T)
        subtract_one item
      in Array
        item.each { |entry| subtract_one entry }
      end
    end
    self
  end

  # Returns a copy of this set with every value in *others* removed.
  def -(*other) : self
    dup.subtract(*other)
  end

  # Returns a copy of this set with every value in *items* added.
  def +(*other) : self
    dup.add(*other)
  end

  # Returns the number of values between `#min` and `#max` inclusive, or `nil`
  # if the set is empty.
  def span? : UInt128?
    low = min?
    high = max?
    return if low.nil? || high.nil?
    self.class.distance(low, high) + 1
  end

  # Returns the number of values between `#min` and `#max` inclusive. Raises
  # `IndexError` if the set is empty.
  def span : UInt128
    span? || raise IndexError.new "empty #{self.class} has no span"
  end

  # Returns the number of distinct ranges stored.
  def size : Int32
    @ranges.size
  end

  # Recomputes and memoizes the number of values in the set.
  def count! : UInt128
    total = 0_u128
    each_range do |range|
      total += self.class.distance(range.begin, range.end) + 1
    end
    @cached_count = total
  end

  # Returns the number of values in the set, recomputing it only when the set
  # has changed since the last call.
  def count : UInt128
    @cached_count || count!
  end

  # Writes this set to *json* as an array of `[begin, end]` pairs.
  #
  # ```
  # SparseRange(Int32).new(list: "1..3,10").to_json # => "[[1,3],[10,10]]"
  # ```
  def to_json(json : JSON::Builder) : Nil
    json.array do
      @ranges.each do |range|
        json.array do
          range.begin.to_json json
          range.end.to_json json
        end
      end
    end
  end

  # Reads a `SparseRange` written by `#to_json`. The pairs need not be sorted,
  # but each must be non-decreasing.
  def self.new(pull : JSON::PullParser)
    location = pull.location
    ranges = [] of Range(T, T)
    pull.read_array do
      pull.read_begin_array
      range_begin = T.new pull
      range_end = T.new pull
      pull.read_end_array
      if range_begin > range_end
        raise JSON::ParseException.new(
          "range end #{range_end} precedes begin #{range_begin}", *location)
      end
      ranges << Range(T, T).new(range_begin, range_end)
    end
    new ranges: ranges, assert: false
  end

  # :nodoc:
  # Returns `high - low` as a `UInt128`, which no pair of `T` values can
  # overflow.
  def self.distance(low : T, high : T) : UInt128
    {% if T.name == "UInt128" %}
      high - low
    {% else %}
      (high.to_i128 - low.to_i128).to_u128
    {% end %}
  end

  # :nodoc:
  def self.offset(value : T) : Int32
    {% if T.name == "UInt128" || T.name == "Int128" %}
      value.to_i32!
    {% else %}
      value.to_i32
    {% end %}
  end

  private def check_type : Nil
    {% raise "#{@type} generic type must have #succ and #pred methods" unless T.has_method?(:succ) %}
    {% raise "#{@type} generic type must have #succ and #pred methods" unless T.has_method?(:pred) %}
  end

  private def trace(message : String) : Nil
    STDERR.puts "#{self.class}: #{message}" if @debug
  end

  # Returns *range* as an inclusive, non-empty range, or `nil` if it holds no
  # values. Raises `ArgumentError` if it is reversed.
  private def normalize(range : Range(T, T)) : Range(T, T)?
    range_begin = range.begin
    range_end = range.end
    if range.exclusive?
      return if range_begin == range_end
      raise ArgumentError.new "#{range}: range end precedes range begin" if range_begin > range_end
      # `range_begin < range_end` puts `range_end` above `T::MIN`, so `#pred`
      # cannot underflow.
      range_end = range_end.pred
    elsif range_begin > range_end
      raise ArgumentError.new "#{range}: range end precedes range begin"
    end
    Range(T, T).new range_begin, range_end
  end

  private def append_normalized(range : Range(T, T)) : Nil
    if normalized = normalize(range)
      @ranges << normalized
    end
  end

  # Returns `true` if *later* overlaps or abuts *earlier*, given that
  # `earlier.begin <= later.begin`.
  private def contiguous_with?(earlier : Range(T, T), later : Range(T, T)) : Bool
    return true if later.begin <= earlier.end
    earlier.end != T::MAX && later.begin == earlier.end.succ
  end

  private def crowded_within?(total : UInt128) : Bool
    values = count
    values >= total - values
  end

  private def invariant_violation : String?
    previous : Range(T, T)? = nil
    @ranges.each_with_index do |range, index|
      if range.exclusive?
        return "range #{index} (#{range}) is exclusive"
      end
      if range.begin > range.end
        return "range #{index} (#{range}) is reversed"
      end
      if previous
        if previous.end >= range.begin
          return "ranges #{index - 1} and #{index} (#{previous}, #{range}) overlap"
        end
        if previous.end != T::MAX && previous.end.succ == range.begin
          return "ranges #{index - 1} and #{index} (#{previous}, #{range}) are adjacent"
        end
      end
      previous = range
    end
    nil
  end

  private def parse(list : String) : Nil
    body = list.strip
    body = body[1...-1].strip if body.starts_with?('[') && body.ends_with?(']')
    return if body.empty?

    scanner = StringScanner.new body
    loop do
      scanner.skip(/\s*/)
      raise ParseException.new "#{list.inspect}: unexpected end of list" if scanner.eos?
      scan_entry scanner, list
      scanner.skip(/\s*/)
      break if scanner.eos?
      unless scanner.scan(/,/)
        raise ParseException.new "#{list.inspect}: expected ',' at #{body[scanner.offset..].inspect}"
      end
    end
  end

  private def scan_entry(scanner : StringScanner, list : String) : Nil
    if scanner.scan(REGEX_RANGEX)
      append_parsed scanner[1], scanner[2], list, exclusive: true
    elsif scanner.scan(REGEX_RANGE)
      append_parsed scanner[1], scanner[2], list, exclusive: false
    elsif scanner.scan(REGEX_INT)
      value = parse_value scanner[0], list
      @ranges << Range(T, T).new(value, value)
    else
      raise ParseException.new "#{list.inspect}: cannot parse #{scanner.rest.inspect}"
    end
  end

  private def append_parsed(from : String, to : String, list : String, exclusive : Bool) : Nil
    range = Range(T, T).new parse_value(from, list), parse_value(to, list), exclusive
    append_normalized range
  rescue error : ArgumentError
    raise ParseException.new "#{list.inspect}: #{error.message}"
  end

  private def parse_value(text : String, list : String) : T
    T.new text
  rescue ArgumentError | OverflowError
    raise ParseException.new "#{list.inspect}: #{text.inspect} does not fit in #{T}"
  end

  private def add_one(value : T) : Nil
    add_one Range(T, T).new(value, value)
  end

  private def add_one(range_to_add : Range(T, T)) : Nil
    normalized = normalize range_to_add
    return if normalized.nil?
    range_to_add = normalized
    dirty!
    trace "add #{range_to_add} to #{@ranges.inspect}"

    if empty?
      @ranges << range_to_add
      return
    end

    # The first stored range that could possibly overlap or abut is the first
    # one ending at or after the value just below `range_to_add.begin`.
    adjacent_to_begin = range_to_add.begin == T::MIN ? T::MIN : range_to_add.begin.pred
    index = @ranges.bsearch_index { |range| range.end >= adjacent_to_begin }

    if index.nil?
      @ranges << range_to_add
      return
    end

    if range_to_add.overlaps_or_abuts? @ranges[index]
      @ranges[index] = @ranges[index].merge! range_to_add
    else
      @ranges.insert index, range_to_add
    end

    # Absorbing `range_to_add` may have closed the gap to the ranges that
    # follow. Everything before `index` is unreachable: it ends below
    # `adjacent_to_begin`, so it neither overlaps nor abuts.
    while (following = @ranges[index + 1]?) && @ranges[index].overlaps_or_abuts?(following)
      @ranges[index] = @ranges[index].merge! following
      @ranges.delete_at index + 1
    end
    trace "add result: #{@ranges.inspect}"
  end

  private def subtract_one(value : T) : Nil
    subtract_one Range(T, T).new(value, value)
  end

  private def subtract_one(range_to_sub : Range(T, T)) : Nil
    return if empty?
    normalized = normalize range_to_sub
    return if normalized.nil?
    range_to_sub = normalized
    dirty!
    trace "subtract #{range_to_sub} from #{@ranges.inspect}"

    index = 0
    while index < @ranges.size
      range = @ranges[index]
      if range.begin > range_to_sub.end
        break # sorted, so nothing further can overlap
      elsif range.end < range_to_sub.begin
        index += 1
      elsif range.begin >= range_to_sub.begin && range.end <= range_to_sub.end
        @ranges.delete_at index
      elsif range.begin < range_to_sub.begin && range.end > range_to_sub.end
        # Split: `range_to_sub` lies strictly inside `range`, so neither `#pred`
        # nor `#succ` can wrap.
        @ranges[index] = Range(T, T).new(range.begin, range_to_sub.begin.pred)
        @ranges.insert index + 1, Range(T, T).new(range_to_sub.end.succ, range.end)
        index += 2
      elsif range.begin < range_to_sub.begin
        @ranges[index] = Range(T, T).new(range.begin, range_to_sub.begin.pred)
        index += 1
      else
        @ranges[index] = Range(T, T).new(range_to_sub.end.succ, range.end)
        index += 1
      end
    end
    trace "subtract result: #{@ranges.inspect}"
  end
end
