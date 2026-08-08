require "spec"
require "../src/sparse_range"
require "bit_array"

alias RangeType = Range(Int32, Int32)

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

# Renders several named range lists as aligned bit grids, so that overlaps and
# gaps between them can be compared by eye.
#
# ```
# compare_ranges [{"before", [1..5]}, {"after", [1..3, 5..5]}]
# ```
def compare_ranges(entries : Array({String, Array(RangeType)}), io : IO = STDOUT,
                   window_size : Int32 = 120) : Nil
  lowest = entries.min_of { |entry| entry[1].min_of(&.begin) }
  highest = entries.max_of { |entry| entry[1].max_of(&.end) }
  rows = entries.map do |entry|
    {
      name:   entry[0],
      ranges: entry[1],
      bits:   fixture_bitarray(entry[1], lowest, highest),
      min:    entry[1].min_of(&.begin),
      max:    entry[1].max_of(&.end),
    }
  end

  rows.each do |row|
    io.printf "%-10s: [%3d - %3d] %s\n", row[:name], lowest, highest,
      row[:ranges].join(", ")
  end
  io << '\n'

  window_start = lowest
  while window_start <= highest
    window_end = (window_start + window_size - 1).clamp(lowest, highest)
    rows.each do |row|
      io.printf "%-10s: %3d ", row[:name], window_start
      (window_start..window_end).each do |position|
        if position < row[:min] || position > row[:max]
          io << '.'
        else
          io << (row[:bits][position - lowest]? ? '*' : '-')
        end
      end
      io.printf " %3d\n", window_end
    end
    window_start += window_size
  end
end

private def fixture_bitarray(list : Array(RangeType), lowest : Int32, highest : Int32) : BitArray
  bitarray = BitArray.new(highest - lowest + 1)
  list.each do |range|
    range.each { |value| bitarray[value - lowest] = true }
  end
  bitarray
end
