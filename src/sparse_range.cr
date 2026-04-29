require "bit_array"
require "string_scanner"
require "json"

require "./constructors"
require "./range_util"

# A SparseRange manages a non-contiguous range of Int values
#
# ### Example
#
# ```
# # Create a SparseRange of Int32
# sparserange = SparseRange(Int32).new
# # Add a value to the SparseRange
# sparserange.add 21
# # Add a range to the SparseRange
# sparserange.add 1234..1243
# # Count the number of distinct ranges in the SparseRange
# sparserange.size # => 2
# # The distance from the minimum to the maximum, inclusive
# sparserange.span # => 1223
# ```
#
# Adjacent ranges are combined, for example:
# ```
# sparserange = SparseRange(Int32).new([1..3, 5..10])
# sparserange.add 4
# sparserange.size # => 1
# sparserange.ranges # => [1..10]
#
class SparseRange(T)
  class ParseException < Exception; end

  VERSION      = "1.0.0"
  REGEX_INT    = %r{\s*([-+]?\d+)\s*}
  REGEX_RANGE  = %r{#{REGEX_INT}\s*\.\.\s*#{REGEX_INT}}
  REGEX_RANGEX = %r{#{REGEX_INT}\s*\.\.\.\s*#{REGEX_INT}}
  REGEX_ENTRY  = %r{#{REGEX_RANGEX}|#{REGEX_RANGE}|#{REGEX_INT}}
  REGEX_LIST   = %r{(?:\s*#{REGEX_ENTRY}\s*,)*\s*(?:#{REGEX_ENTRY})?\s*}

  getter ranges : Array(Range(T, T))
  getter count : T? = nil
  property? debug

  include JSON::Serializable

  def initialize(*, @ranges, assert : Bool = true, sort : Bool? = nil, @debug : Bool = ENV["SPARSE_RANGE_DEBUG"]? ? true : false)
    {% raise "#{@type} generic type must have #succ and #prev methods" unless T.has_method?(:succ) %}
    STDERR.puts "debugging on" if @debug
    if assert
      assert
    elsif sort != false
      sort!
    end
  end

  def initialize(list : Array(Range(T, T) | Array(Range(T, T)) | T), assert : Bool = true, sort : Bool? = nil, @debug : Bool = ENV["SPARSE_RANGE_DEBUG"]? ? true : false)
    {% raise "#{@type} generic type must have #succ and #prev methods" unless T.has_method?(:succ) %}
    STDERR.puts "debugging on" if @debug
    @ranges = [] of Range(T, T)
    if @debug
      STDERR.puts "initialize(list: #{list.inspect})" if @debug
    end
    list.each do |entry|
      case entry
      when Range(T, T)
        STDERR.puts "<< Range #{entry.inspect}" if @debug
        @ranges << entry
      when Array(Range(T, T))
        STDERR.puts "+= Array #{entry.inspect}" if @debug
        @ranges += entry
      when T
        STDERR.puts "<< Int #{entry}" if @debug
        @ranges << Range(T, T).new entry, entry
      else
        raise "#{entry}: cannot handle a #{typeof(entry)}"
      end
      # self.add entry
    end
    if assert
      assert!
    elsif sort != false
      sort!
    end
  end

  def initialize(@debug : Bool = ENV["SPARSE_RANGE_DEBUG"]? ? true : false)
    {% raise "#{@type} generic type must have #succ and #prev methods" unless T.has_method?(:succ) %}
    STDERR.puts "debugging on" if @debug
    @ranges = [] of Range(T, T)
  end

  def initialize(*, list : String, @debug : Bool = ENV["SPARSE_RANGE_DEBUG"]? ? true : false)
    {% raise "#{@type} generic type must have #succ and #prev methods" unless T.has_method?(:succ) %}
    STDERR.puts "debugging on" if @debug
    @ranges = [] of Range(T, T)
    if list =~ %r{\A\s*\[\s*(#{REGEX_LIST})\s*\]\s*\z} || list =~ %r{\A\s*(#{REGEX_LIST})\s*\z}
      scan = StringScanner.new($1)
      while !scan.eos?
        case scan
        when .scan %r{\s*#{REGEX_RANGEX}\s*(?:,|\z)}
          @ranges << (T.new(scan[1])...T.new(scan[2]))
        when .scan %r{\s*#{REGEX_RANGE}\s*(?:,|\z)}
          @ranges << (T.new(scan[1])..T.new(scan[2]))
        when .scan %r{\s*#{REGEX_INT}\s*(?:,|\z)}
          b = T.new(scan[1])
          @ranges << (b..b)
        else
          raise ParseException.new "cannot parse #{scan.inspect}"
        end
      end
    end
  end

  def clear
    @ranges.clear
  end

  def invert
    r = SparseRange(T).new
    r << (T::MIN..T::MAX)
    each_range do |range|
      r -= range
    end
    r
  end

  def invert!
    range
  end

  def each
    Iterator.chain(@ranges.map(&.each))
  end

  def each_range
    @ranges.each
  end

  def each(&)
    @ranges.each do |range|
      range.each do |int|
        yield int
      end
    end
  end

  def each_excluded(start_at : T? = min?, end_at : T? = max?, &)
    return if start_at.nil? || end_at.nil? || empty?
    ptr = start_at
    ranges.each do |range|
      if ptr <= end_at
        if ptr < range.begin
          (ptr...range.begin).each { |value| yield value }
        end
        ptr = range.end.succ
      end
    end
    if ptr <= end_at
      (ptr..end_at).each { |value| yield value }
      ptr = end_at
    end
  end

  def each_range(&)
    @ranges.each do |range|
      yield range
    end
  end

  def empty?
    @ranges.size == 0
  end

  def min? : T?
    if @ranges.size > 0
      @ranges[0].begin
    else
      nil
    end
  end

  def min : T?
    self.min? || raise IndexError.new "empty #{self.class} has no min"
  end

  def max? : T?
    if @ranges.size > 0
      @ranges[-1].end
    else
      nil
    end
  end

  def max
    self.max? || raise IndexError.new "cannot compute maximum of empty SparseRange"
  end

  def dup
    SparseRange(T).new.tap do |new_sparse_range|
      self.each_range do |range|
        new_sparse_range << range
      end
    end
  end

  macro def_to(method_name, target_type)
    def to_{{method_name.id}}? : SparseRange({{target_type.id}})?
      if SparseRange({{target_type.id}}) === self.class
        self.dup
      elsif empty?
        SparseRange({{target_type.id}}).new
      elsif min < {{target_type.id}}::MIN
        nil
      elsif max > {{target_type.id}}::MAX
        nil
      else
        r = SparseRange({{target_type.id}}).new
        self.each_range do |range|
          r << ({{target_type.id}}.new(range.begin) .. {{target_type.id}}.new(range.end))
        end
        r
      end
    end
  end

  # we don't bother with UInt8 and Int8, because it'd almost surely be faster and use
  # less memory to use a BitVector

  def_to(:u128, UInt128)
  def_to(:i128, Int128)
  def_to(:u64, UInt64)
  def_to(:i64, Int64)
  def_to(:u32, UInt32)
  def_to(:i32, Int32)
  def_to(:u16, UInt16)
  def_to(:i16, Int16)

  # def to_u64? : SparseRange(UInt64)?
  #   if empty?
  #     SparseRange(UInt64).new
  #   elsif min < UInt64::MIN
  #     nil
  #   elsif max > UInt64::MAX
  #     nil
  #   else
  #     r = SparseRange(UInt64).new
  #     self.each_range do |range|
  #       r << (UInt64.new(range.begin)..UInt64.new(range.end))
  #     end
  #     r
  #   end
  # end

  def sort!
    if @ranges.size < 2
      STDERR.puts "size: #{@ranges.size}, no sort needed" if @debug
      return self
    end
    STDERR.puts "sort!" if @debug
    old_ranges = @ranges.sort { |a, b| a.begin <=> b.begin }
    STDERR.puts "before: #{old_ranges.inspect}" if @debug
    @ranges = Array(Range(T, T)).new(old_ranges.size)
    @ranges << old_ranges.shift
    old_ranges.each do |this_range|
      last_range = @ranges[-1]
      if this_range.begin.pred <= last_range.end
        @ranges[-1] = Range(T, T).new last_range.begin, this_range.end
      else
        @ranges << this_range
      end
    end
    STDERR.puts "after: #{@ranges.inspect}" if @debug
    self
  end

  def assert?
    case @ranges.size
    when 0, 1
      STDERR.puts "assert? #{@ranges.size} entries, so true" if @debug
      true
    else
      STDERR.puts "assert? #{@ranges.size} entries: #{@ranges.inspect}" if @debug
      index = 1
      while index < @ranges.size
        STDERR.puts "assert? check @ranges[#{index - 1}] >= @ranges[#{index}].begin.pred: #{@ranges[index - 1]} >= #{@ranges[index].begin.pred}" if @debug
        if @ranges[index - 1].end >= @ranges[index].begin.pred
          return false
        end
        index += 1
      end
    end
    true
  end

  def assert!
    case @ranges.size
    when 0, 1
      STDERR.puts "assert! #{@ranges.size} entries, so true" if @debug
      true
    else
      STDERR.puts "assert! #{@ranges.size} entries: #{@ranges.inspect}" if @debug
      index = 1
      while index < @ranges.size
        STDERR.puts "assert! check @ranges[#{index - 1}] >= @ranges[#{index}].begin.pred: #{@ranges[index - 1]} >= #{@ranges[index].begin.pred}" if @debug
        if @ranges[index - 1].end >= @ranges[index].begin.pred
          raise "assertion failed at index #{index}: #{@ranges[index - 1]}, #{@ranges[index]}: invalid sequencing"
        end
        index += 1
      end
    end
    true
  end

  # Return true if >= 50% of the values between #min and #max are included in the SparseRange
  def crowded?(span _span : T? = span?) : Bool
    if _span
      count * 2 >= _span
    else
      false
    end
  end

  def crowded?(lower_limit : T, upper_limit : T) : Bool
    count * 2 >= (upper_limit - lower_limit + 1)
  end

  def crowded?(range : Range(T, T)) : Bool
    count * 2 >= range.size
  end

  def to_bitarray
    return BitArray.new(0) if empty?
    min_value = min
    raise ArgumentError.new "don't know how to include negative numbers in a BitArray (#{self.min}..#{self.max})" if min_value < 0
    max_value = max

    # if the SparseRange is crowded we start with an array of 1s and use the inverted
    # inverted ranges to set zeros
    if crowded?
      bitarray = BitArray.new(max_value, true)
      self.each_excluded do |value|
        bitarray[value] = false
      end
      bitarray
    else
      bitarray = BitArray.new(max_value, false)
      self.each do |value|
        bitarray[value] = true
      end
      bitarray
    end
  end

  def to_bitstring
    String.build(self.count) do |str|
      to_bitstring(str)
    end
  end

  def to_bitstring(io)
    self.to_bitarray.each do |value|
      io << (value ? '1' : '0')
    end
  end

  # def overlaps?(a, b)
  #   a.overlaps? b
  # if a.includes?(b.begin) || a.includes?(b.end) || b.includes?(a.begin) || b.includes?(a.end)
  #   true
  # elsif a.begin < b.begin && a.end > b.end
  #   true
  # elsif b.begin < a.begin && b.end > a.end
  #   true
  # elsif a.begin == b.end.succ || a.end == b.begin.pred
  #   true
  # else
  #   false
  # end
  # end

  # def abuts?(a, b)
  #   a.abuts? b
  # end

  # def overlaps_or_abuts?(a, b)
  #   a.overlaps?(b) || a.abuts?(b)
  # end

  def <<(value)
    self.add value
  end

  def dirty!
    @count = nil
  end

  private def add_one(value : T)
    dirty!
    # @cursor = nil
    self.add Range(T, T).new value, value
  end

  def subtract(*other : T | Range(T, T) | Array(T) | Array(Range(T, T)) | Array(T | Range(T, T))) : self
    other.each do |item|
      case item
      in T, Range(T, T)
        subtract_one item
      in Array
        item.each do |entry|
          subtract_one entry
        end
      end
    end
    self
  end

  def -(*other) : self
    dup.subtract(*other)
  end

  def +(*other) : self
    dup.add(*other)
  end

  def <<(*args) : self
    add(*args)
  end

  private def subtract_one(value : T) : Nil
    subtract_one Range(T, T).new value, value
  end

  private def subtract_one(range_to_sub : Range(T, T)) : Nil
    return if empty?

    if range_to_sub.exclusive?
      range_to_sub = (range_to_sub.begin)..(range_to_sub.end.pred)
    end
    dirty!

    @ranges.reject! do |range|
      range_to_sub.includes?(range.begin) && range_to_sub.includes?(range.end)
      # range.begin >= range_to_sub.begin && range.end <= range_to_sub.end
    end

    # Because of the reject! above, we know that range.begin != range.end for any
    # range that overlaps. And we know that there can be at most two overlapping ranges,
    # since any ranges in between would have been removed.
    #
    # ### TODO: use a binary search to find the first of the overlapping ranges, if any,
    # ###       and then check its next neighbor for overlap as well.

    idx = 0
    while idx < @ranges.size
      begin
        range = @ranges[idx]
        break if range.begin > range_to_sub.end  # no more could overlap, so stop checking
        next unless range.overlaps? range_to_sub # does not overlap, check the next one
        if range.includes?(range_to_sub.begin) && range.includes?(range_to_sub.end) && (range.end != range_to_sub.end || range.begin != range_to_sub.begin)
          preceding_range = (range.begin..range_to_sub.begin.pred)
          following_range = (range_to_sub.end.succ..range.end)
          @ranges[idx] = preceding_range
          @ranges.insert(idx + 1, following_range)
        elsif range.end == range_to_sub.begin
          @ranges[idx] = (range.begin..range.end.pred)
        elsif range.begin == range_to_sub.end
          @ranges[idx] = (range.begin.succ..range.end)
        elsif range.includes? range_to_sub.begin
          @ranges[idx] = (range.begin..range_to_sub.begin.pred)
        elsif range.includes? range_to_sub.end
          @ranges[idx] = (range_to_sub.end.succ..range.end)
        end
      ensure
        idx += 1
      end
      self
    end
  end

  def add(*items : T | Range(T, T) | Array(T) | Array(Range(T, T)) | Array(T | Range(T, T))) : self
    items.each do |item|
      case item
      when T, Range(T, T)
        add_one item
      when Array
        item.each { |entry| add_one entry }
      end
    end
    self
  end

  private def add_one(range_to_add : Range(T, T)) : Nil
    dirty!

    if range_to_add.exclusive?
      range_to_add = (range_to_add.begin)..(range_to_add.end.pred)
    end

    if empty?
      @ranges << range_to_add
    elsif range_to_add.begin == T::MIN
      if @ranges[0].begin > range_to_add.end
        @ranges.unshift range_to_add
      else
        @ranges[0] = Range(T, T).new(range_to_add.begin, @ranges[0].end)
      end
    else
      adjacent_to_begin = range_to_add.begin.pred
      index = @ranges.bsearch_index { |range1| range1.end >= adjacent_to_begin }
      case index
      when nil
        @ranges << range_to_add
      when 0
        if range_to_add.overlaps_or_abuts? @ranges[0]
          @ranges[0] = range_to_add.merge @ranges[0]
        else
          @ranges.unshift range_to_add
        end
        while @ranges[1]? && @ranges[0].overlaps_or_abuts? @ranges[1]
          @ranges[1] = @ranges[0].merge! @ranges[1]
          @ranges.shift
        end
      else
        if range_to_add.overlaps_or_abuts? @ranges[index - 1]
          @ranges[index - 1] = @ranges[index - 1].merge! range_to_add
        elsif range_to_add.overlaps_or_abuts? @ranges[index]
          @ranges[index] = @ranges[index].merge! range_to_add
        else
          @ranges.insert(index, range_to_add)
        end
        if @ranges[index]? && @ranges[index].overlaps_or_abuts? @ranges[index - 1]
          while @ranges[index]? && @ranges[index].overlaps_or_abuts? @ranges[index - 1]
            @ranges[index - 1] = @ranges[index - 1].merge! @ranges[index]
            @ranges.delete_at(index)
          end
        else
          while @ranges[index + 1]? && @ranges[index].overlaps_or_abuts?(@ranges[index + 1])
            @ranges[index + 1] = @ranges[index + 1].merge! @ranges[index]
            @ranges.delete_at(index)
          end
        end
      end
    end
  end

  def span?
    if (_max = self.max?) && (_min = self.min?)
      _max - _min + 1
    else
      nil
    end
  end

  def span
    self.span? || raise IndexError.new "empty #{self.class} has no span"
  end

  def size
    @ranges.size
  end

  def count!
    _count = 0
    each_range do |range|
      _count += range.size
    end
    @count = _count
  end

  def count
    if c = @count
      c
    else
      count!
    end
  end
end
