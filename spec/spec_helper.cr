require "spec"
require "../src/sparse_range"
require "bit_array"

FIXTURES = [
  [10..19, 30..39, 50..59],
  [-19..-10, 10..19, 30..39],
  [-59..-50, -39..-30, -19..-10],
  [] of RangeType,
  [10..10, 20..20],
]

def fixture(index : Int32 = 0)
  SparseRange(Int32).new FIXTURES[index]
end

def compare_ranges(list list_ : Array({String, Array(Int32)}))
  min = list_.min_of { |entry| entry[1].min_of(&.begin) }
  max = list_.max_of { |entry| entry[1].max_of(&.end) }
  # min = list_.map { |entry| entry[1].map(&.begin).min }.min
  # max = list_.map { |entry| entry[1].map(&.end).max }.max
  list = list_.map { |entry| {name: entry[0], ranges: entry[1], bits: to_bitarray(entry[1], min, max), min: entry[1].min_of(&.begin), max: entry[1].max_of(&.end)} }
  window_size = 120
  list.each do |tuple|
    printf "%-10s: [%3d - %3d] %s\n", tuple[:name], min, max, tuple[:ranges].map(&.to_s).join(", ")
  end
  print "\n"
  window_idx = min
  while window_idx < max
    window_end = (window_idx + window_size - 1).clamp(min, max)
    list.each do |tuple|
      printf "%-10s: %3d ", tuple[:name], window_idx
      (window_idx..window_end).each do |idx|
        if idx < tuple[:min] || idx > tuple[:max]
          print "."
        else
          print tuple[:bits][idx]? ? "*" : "-"
        end
      end
      printf " %3d\n", window_end
    end
    window_idx += window_size
  end
end

def to_bitarray(list : Array(RangeType), min, max)
  bitarray = BitArray.new(max - min + 1)
  list.each do |range|
    range.each do |value|
      raise "#{value} - #{min} = #{value - min}" if value - min < 0
      bitarray[value - min] = true
    end
  end
  bitarray
end
