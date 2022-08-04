# A sparse range of integers

require "bit_array"

class SparseRange
  VERSION = "0.1.0"

  def new(list : Array(::Int32 | Range(::Int32, ::Int32)))
    SparseRange::Int.new list
  end

  def new(list : Array(Float64 | Range(Float64, Float64)))
    SparseRange::Float64.new list
  end
end

class SparseRange::Int32 < SparseRange
  alias NumType = ::Int32
  alias RangeType = Range(NumType, NumType)
  property ranges : Array(RangeType)
  getter min : NumType? = nil
  getter max : NumType? = nil
  property debug : Bool = false

  def initialize(*, @ranges, assert : Bool = true, sort : Bool? = nil)
    if assert
      assert!
    elsif sort != false
      sort!
    end
  end

  def initialize(list : Array(RangeType | Array(RangeType) | NumType), assert : Bool = true, sort : Bool? = nil)
    @ranges = [] of RangeType
    list.each do |entry|
      case entry
      when RangeType
        @ranges << entry
      when Array(RangeType)
        @ranges += entry
      when NumType
        @ranges << RangeType.new entry, entry
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
    set_min = @ranges.map(&.begin).min
    set_max = @ranges.map(&.end).max
  end

  def initialize
    @ranges = [] of RangeType
  end

  private def set_min_max(value)
    set_min value.begin
    set_max value.end
    {value.begin, value.end}
  end

  private def set_min_max(min, max)
    set_min min
    set_max max
    {min, max}
  end

  private def set_min(value)
    m = @min || value
    @min = value if value < m
    @min
  end

  private def set_max(value)
    m = @max || value
    @max = value if value > m
    @max
  end

  def min
    @min || min!
  end

  def min!
    @min = @ranges.map(&.begin).min
    @min
  end

  def max
    @max || max!
  end

  def max!
    @max = @ranges.map(&.end).max
    @max
  end

  def minmax
    {min, max}
  end

  def minmax!
    {min!, max!}
  end

  def sort!
    return self if @ranges.size < 2
    old_ranges = @ranges.sort { |a, b| a.begin <=> b.begin }
    @ranges = Array(RangeType).new(old_ranges.size)
    @ranges << old_ranges.shift
    old_ranges.each do |this_range|
      last_range = @ranges[-1]
      if this_range.begin.pred <= last_range.end
        @ranges[-1] = RangeType.new last_range.begin, this_range.end
      else
        @ranges << this_range
      end
    end
    @ranges
  end

  def assert!
    ranges_copy = @ranges.clone
    self.sort!
    if @ranges != ranges_copy
      STDERR.puts "INVALID RANGES: #{ranges_copy.map(&.to_s).join(", ")}"
      STDERR.puts "SHOULD BE: #{@ranges.map(&.to_s).join(", ")}"
      raise "assertion failed!"
    end
  end

  def to_bitarray
    bitarray = BitArray.new(self.size)
    @ranges.each do |range|
      range.each do |value|
        bitarray[value - min] = true
      end
    end
    return bitarray
  end

  def overlaps?(a, b)
    if a.includes?(b.begin) || a.includes?(b.end) || b.includes?(a.begin) || b.includes?(a.end)
      true
    elsif a.begin < b.begin && a.end > b.end
      true
    elsif b.begin < a.begin && b.end > a.end
      true
    elsif a.begin == b.end.succ || a.end == b.begin.pred
      true
    else
      false
    end
  end

  def add(value : NumType)
    # STDERR.puts "\nRANGES: #{@ranges.inspect}"
    if idx = ranges.bsearch_index { |r| r.end >= value.pred }
      found_range = ranges[idx]
      # STDERR.puts "FOUND: ##{idx} = #{found_range}"
      val_begin = found_range.begin
      val_end = found_range.end
      if val_begin <= value && val_end >= value
        # STDERR.puts "#{value} is >= #{val_begin} and <= #{val_end}"
        # "#{value} is included in a range already: #{found_range}"
        # return self
      elsif val_begin == value.succ
        new_range = RangeType.new value, val_end
        # puts "#{value} precedes #{found_range} -> #{new_range}"
        ranges[idx] = new_range
        # STDERR.puts "##{idx}: #{found_range} -> #{new_range}"
      elsif val_begin > value
        new_range = RangeType.new value, value
        if idx == 0
          # puts "#{value} is before the first range #{found_range}, inserting #{new_range}"
        else
          # puts "#{value} is between #{ranges[idx - 1]} and #{found_range}, inserting #{new_range}"
        end
        # the value is not part of this range or the previous, so insert a new range
        ranges.insert(idx, new_range)
      elsif val_end == value.pred
        new_range = RangeType.new val_begin, value
        # puts "#{value} succeeds #{found_range} -> #{new_range}"
        ranges[idx] = new_range
      else
        # puts "ERROR: #{value}: idx is #{idx} but no criteria matched"
      end
    else
      new_range = RangeType.new value, value
      # puts "#{value} is after last range #{ranges[-1]?}, appending #{new_range}"
      ranges << new_range
    end
    @min = Math.min(min || value, value)
    @max = Math.max(max || value, value)
  end

  def <<(value : NumType)
    self.add value
  end

  # naive, simple implementation
  # def add_(range_to_add : RangeType)
  #   range_to_add.each { |value| self.add value }
  # end

  def merge_ranges?(a, b)
    if overlaps? a, b
      RangeType.new Math.min(a.begin, b.begin), Math.max(a.end, b.end)
    else
      nil
    end
  end

  def merge_ranges(a, b)
    merge_ranges?(a, b) || raise "Cannot merge #{a} with #{b}: they do not overlap"
  end

  # def add(range_to_add : RangeType)
  #   if @ranges.size == 0
  #     @ranges << range_to_add
  #   else
  #     new_ranges = Array(RangeType).new(@ranges.size)
  #     new_ranges << @ranges.shift
  #     @ranges.each do |old_range|
  #       if overlaps? old_range, new_ranges[-1]
  #         new_ranges[-1] = merge_ranges old_range, new_ranges[-1]
  #       else
  #         new_ranges << old_range
  #       end
  #     end
  #     @ranges = new_ranges
  #   end
  # puts "ADD: #{range_to_add}" if @debug
  # range_to_add_begin = range_to_add.begin
  # range_to_add_end = range_to_add.end
  # raise "#{range_to_add}: range must be ascending" if range_to_add_begin > range_to_add_end
  # if @ranges.size == 0
  #   @ranges << range_to_add
  #   puts "empty ranges -> #{range_to_add}" if @debug
  #   return self
  # end
  # adjacent = range_to_add.begin.pred
  # index = @ranges.bsearch_index { |r| r.begin >= adjacent }
  # while index < @ranges.size
  #   if overlaps? @ranges[index], range_to_add
  #     @ranges[index] =
  # end
  # first_index = @ranges.bsearch_index { |r| r.begin >= range_to_add_begin.pred }
  # second_index = @ranges.bsearch_index { |r| r.end >= range_to_add_end.succ }
  # puts "RANGES: #{@ranges}" if @debug
  # puts "indices of #{range_to_add}: #{first_index} = #{first_index ? @ranges[first_index]? : nil}, #{second_index} = #{second_index ? @ranges[second_index]? : nil}" if @debug
  # # if !first_index && second_index

  # # end
  # # if first_index && second_index
  # #   first_found = @ranges[first_index]
  # #   second_found = @ranges[second_index]
  # #   if first_index == second_index
  # #     # just one range hit
  # #     puts "just one range hit" if @debug
  # #     if range_to_add_end.succ >= first_found.begin
  # #       new_range = RangeType.new [first_found.begin, range_to_add_begin].min, [first_found.end, range_to_add_end].max
  # #       puts "#{range_to_add} overlaps #{first_found} -> #{new_range}" if @debug
  # #       @ranges[first_index] = new_range
  # #     else
  # #       # must be below?
  # #       puts "#{range_to_add} is below #{first_found}, inserting into first position" if @debug
  # #       @ranges.insert(first_index, range_to_add)
  # #     end
  # #   elsif range_to_add_end.succ >= second_found.begin
  # #     # merges all of them
  # #     new_range = RangeType.new [first_found.begin, range_to_add_begin].min, [second_found.end, range_to_add_end].max
  # #     puts "#{range_to_add} is merging #{second_index - first_index + 1} ranges: #{@ranges[first_index..second_index].map(&.to_s).join(", ")} -> #{new_range}" if @debug
  # #     @ranges[first_index, second_index - first_index + 1] = new_range
  # #   end
  # # elsif first_index
  # #   # merge the found range with all succeeding ranges
  # #   found_range = ranges[first_index]
  # #   new_range = RangeType.new [found_range.begin, range_to_add_begin].min, range_to_add_end
  # #   puts "#{range_to_add} is merging #{@ranges.size - first_index} ranges: #{@ranges[first_index..].map(&.to_s).join(", ")} -> #{new_range}" if @debug
  # #   @ranges[first_index, @ranges.size - first_index] = new_range
  # # elsif second_index
  # #   found_range = ranges[second_index]
  # #   puts "ERROR: matched ranges ---, #{second_index} (---, #{found_range}), don't know what to do!" if @debug
  # # else
  # #   puts "#{range_to_add} is after the last range (#{@ranges[-1]?}), appending it" if @debug
  # #   @ranges << range_to_add
  # # end
  # @min = min ? Math.min(min || range_to_add_begin, range_to_add_begin) : range_to_add_begin
  # @max = max ? Math.max(max || range_to_add_end, range_to_add_end) : range_to_add_end
  # end

  def add(range_to_add : RangeType)
    if @ranges.size == 0
      @ranges << range_to_add
    else
      adjacent_to_begin = range_to_add.begin.pred
      index = @ranges.bsearch_index { |r| r.end >= adjacent_to_begin }
      case index
      when nil
        @ranges << range_to_add
      when 0
        if overlaps? range_to_add, @ranges[0]
          @ranges[0] = merge_ranges range_to_add, @ranges[0]
        else
          @ranges.unshift range_to_add
        end
        while @ranges[1]? && overlaps? @ranges[0], @ranges[1]
          @ranges[1] = merge_ranges @ranges[0], @ranges[1]
          @ranges.shift
        end
      else
        if overlaps? @ranges[index - 1], range_to_add
          @ranges[index - 1] = merge_ranges @ranges[index - 1], range_to_add
        elsif overlaps? @ranges[index], range_to_add
          @ranges[index] = merge_ranges @ranges[index], range_to_add
        else
          @ranges.insert(index, range_to_add)
        end
        if @ranges[index]? && overlaps? @ranges[index - 1], @ranges[index]
          while @ranges[index]? && overlaps? @ranges[index - 1], @ranges[index]
            @ranges[index - 1] = merge_ranges @ranges[index - 1], @ranges[index]
            @ranges.delete_at(index)
          end
        else
          while @ranges[index + 1]? && overlaps?(@ranges[index + 1], @ranges[index])
            @ranges[index + 1] = merge_ranges @ranges[index + 1], @ranges[index]
            @ranges.delete_at(index)
          end
        end
      end
    end
  end

  def size
    @max - @min + 1
  end
end

class SparseRange::Float64 < SparseRange
  alias NumType = Float64
  alias RangeType = Range(NumType, NumType)
  property ranges : Array(RangeType)
  getter min : NumType? = nil
  getter max : NumType? = nil

  def initialize(list : Array(NumType | RangeType))
    @ranges = [] of RangeType
    list.each do |entry|
      self << entry
    end
  end
end
