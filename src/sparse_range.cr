# A sparse range of integers

require "bit_array"

class SparseRange(T)
  VERSION = "0.1.0"

  # alias RangeType = Range(T, T)
  property ranges : Array(Range(T, T))
  getter min : T? = nil
  getter max : T? = nil
  property debug : Bool = false
  property cursor : T? = nil

  include Iterator(T)

  def initialize(*, @ranges, assert : Bool = true, sort : Bool? = nil)
    if assert
      assert!
    elsif sort != false
      sort!
    end
  end

  def initialize(list : Array(Range(T, T) | Array(Range(T, T)) | T), assert : Bool = true, sort : Bool? = nil)
    @ranges = [] of Range(T, T)
    list.each do |entry|
      case entry
      when Range(T, T)
        @ranges << entry
      when Array(Range(T, T))
        @ranges += entry
      when T
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
    set_min = @ranges.map(&.begin).min
    set_max = @ranges.map(&.end).max
  end

  def initialize
    @ranges = [] of Range(T, T)
  end

  def next
    if !@cursor
      @cursor = self.min
    end
  end

  def succ(thing : Int)
    thing.succ
  end

  def succ(thing : Float)
    thing.next_float
  end

  def pred(thing : Int)
    thing.pred
  end

  def pred(thing : Float)
    thing.prev_float
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
    if r = @ranges[0]?
      r.begin
    else
      raise IndexError.new "cannot compute minimum of empty SparseRange"
    end
    # @min || min!
  end

  def min!
    # @min = @ranges.map(&.begin).min
    # @min
  end

  def max
    if @ranges.size > 0
      @ranges[-1].end
    else
      raise IndexError.new "cannot compute maximum of empty SparseRange"
    end
    # @max || max!
  end

  def sort!
    return self if @ranges.size < 2
    old_ranges = @ranges.sort { |a, b| a.begin <=> b.begin }
    @ranges = Array(Range(T, T)).new(old_ranges.size)
    @ranges << old_ranges.shift
    old_ranges.each do |this_range|
      last_range = @ranges[-1]
      if pred(this_range.begin) <= last_range.end
        @ranges[-1] = Range(T, T).new last_range.begin, this_range.end
      else
        @ranges << this_range
      end
    end
    @ranges
  end

  def assert?
    case @ranges.size
    when 0, 1
      true
    else
      index = 1
      while index < @ranges.size
        if @ranges[index - 1].end >= pred(@ranges[index].begin)
          return false
        end
      end
    end
    true
  end

  def assert!
    assert? || raise "assertion failed at index #{index}: #{@ranges[index - 1]}, #{@ranges[index]}: invalid sequencing"
  end

  def to_bitarray
    min_value = min
    bitarray = BitArray.new(self.size)
    @ranges.each do |range|
      range.each do |value|
        bitarray[value - min_value] = true
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
    elsif a.begin == succ(b.end) || a.end == pred(b.begin)
      true
    else
      false
    end
  end

  def add(value : T)
    # STDERR.puts "\nRANGES: #{@ranges.inspect}"
    if idx = ranges.bsearch_index { |r| r.end >= pred(value) }
      found_range = ranges[idx]
      # STDERR.puts "FOUND: ##{idx} = #{found_range}"
      val_begin = found_range.begin
      val_end = found_range.end
      if val_begin <= value && val_end >= value
        # STDERR.puts "#{value} is >= #{val_begin} and <= #{val_end}"
        # "#{value} is included in a range already: #{found_range}"
        # return self
      elsif val_begin == succ(value)
        new_range = Range(T, T).new value, val_end
        # puts "#{value} precedes #{found_range} -> #{new_range}"
        ranges[idx] = new_range
        # STDERR.puts "##{idx}: #{found_range} -> #{new_range}"
      elsif val_begin > value
        new_range = Range(T, T).new value, value
        if idx == 0
          # puts "#{value} is before the first range #{found_range}, inserting #{new_range}"
        else
          # puts "#{value} is between #{ranges[idx - 1]} and #{found_range}, inserting #{new_range}"
        end
        # the value is not part of this range or the previous, so insert a new range
        ranges.insert(idx, new_range)
      elsif val_end == pred(value)
        new_range = Range(T, T).new val_begin, value
        # puts "#{value} succeeds #{found_range} -> #{new_range}"
        ranges[idx] = new_range
      else
        # puts "ERROR: #{value}: idx is #{idx} but no criteria matched"
      end
    else
      new_range = Range(T, T).new value, value
      # puts "#{value} is after last range #{ranges[-1]?}, appending #{new_range}"
      ranges << new_range
    end
    @min = Math.min(min || value, value)
    @max = Math.max(max || value, value)
  end

  def <<(value : T)
    self.add value
  end

  def merge_ranges?(a, b)
    if overlaps? a, b
      Range(T, T).new Math.min(a.begin, b.begin), Math.max(a.end, b.end)
    else
      nil
    end
  end

  def merge_ranges(a, b)
    merge_ranges?(a, b) || raise "Cannot merge #{a} with #{b}: they do not overlap"
  end

  def add(range_to_add : Range(T, T))
    if @ranges.size == 0
      @ranges << range_to_add
    else
      adjacent_to_begin = pred(range_to_add.begin)
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

# class SparseRange::Float64 < SparseRange
#   alias T = Float64
#   alias Range(T, T) = Range(T, T)
#   property ranges : Array(Range(T, T))
#   getter min : T? = nil
#   getter max : T? = nil

#   def initialize(list : Array(T | Range(T, T)))
#     @ranges = [] of Range(T, T)
#     list.each do |entry|
#       self << entry
#     end
#   end
# end
