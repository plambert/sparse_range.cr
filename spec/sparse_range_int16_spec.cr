require "./spec_helper"

Spectator.describe SparseRange(Int16) do
  let(sparserange) { SparseRange(Int16).new list: [-19_i16..-10_i16, 10_i16..19_i16, 30_i16..39_i16] }

  it "can be created empty" do
    sparserange = SparseRange(Int16).new
    expect(sparserange.ranges.size).to eq 0
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange(Int16).new list: [1_i16..10_i16, 21_i16..30_i16]
    expect(sparserange.ranges.size).to eq 2
  end
  it "calculates the min/max correctly" do
    expect(sparserange.min).to eq -19
    expect(sparserange.max).to eq 39
  end
  it "adds integers" do
    sparserange.add 40
    expect(sparserange.ranges).to eq [-19_i16..-10_i16, 10_i16..19_i16, 30_i16..40_i16]
    sparserange.add 20
    expect(sparserange.ranges).to eq [-19_i16..-10_i16, 10_i16..20_i16, 30_i16..40_i16]
    sparserange.add -20
    expect(sparserange.ranges).to eq [-20_i16..-10_i16, 10_i16..20_i16, 30_i16..40_i16]
    sparserange.add 45
    expect(sparserange.ranges).to eq [-20_i16..-10_i16, 10_i16..20_i16, 30_i16..40_i16, 45_i16..45_i16]
    sparserange.add 25
    expect(sparserange.ranges).to eq [-20_i16..-10_i16, 10_i16..20_i16, 25_i16..25_i16, 30_i16..40_i16, 45_i16..45_i16]
    sparserange.add 15
    expect(sparserange.ranges).to eq [-20_i16..-10_i16, 10_i16..20_i16, 25_i16..25_i16, 30_i16..40_i16, 45_i16..45_i16]
    sparserange.add -5
    expect(sparserange.ranges).to eq [-20_i16..-10_i16, -5_i16..-5_i16, 10_i16..20_i16, 25_i16..25_i16, 30_i16..40_i16, 45_i16..45_i16]
    sparserange.add -25
    expect(sparserange.ranges).to eq [-25_i16..-25_i16, -20_i16..-10_i16, -5_i16..-5_i16, 10_i16..20_i16, 25_i16..25_i16, 30_i16..40_i16, 45_i16..45_i16]
  end
  it "adds ranges" do
    sparserange = SparseRange(Int16).new list: [-25_i16..-25_i16, -20_i16..-10_i16, -5_i16..-5_i16, 10_i16..20_i16, 25_i16..25_i16, 30_i16..40_i16, 45_i16..45_i16]
    sparserange.add(27_i16..28_i16)
    expect(sparserange.ranges).to eq [-25_i16..-25_i16, -20_i16..-10_i16, -5_i16..-5_i16, 10_i16..20_i16, 25_i16..25_i16, 27_i16..28_i16, 30_i16..40_i16, 45_i16..45_i16]
    sparserange.add(50_i16..59_i16)
    expect(sparserange.ranges).to eq [-25_i16..-25_i16, -20_i16..-10_i16, -5_i16..-5_i16, 10_i16..20_i16, 25_i16..25_i16, 27_i16..28_i16, 30_i16..40_i16, 45_i16..45_i16, 50_i16..59_i16]
    sparserange.add(45_i16..50_i16)
    expect(sparserange.ranges).to eq [-25_i16..-25_i16, -20_i16..-10_i16, -5_i16..-5_i16, 10_i16..20_i16, 25_i16..25_i16, 27_i16..28_i16, 30_i16..40_i16, 45_i16..59_i16]
    sparserange.add(-5_i16..10_i16)
    expect(sparserange.ranges).to eq [-25_i16..-25_i16, -20_i16..-10_i16, -5_i16..20_i16, 25_i16..25_i16, 27_i16..28_i16, 30_i16..40_i16, 45_i16..59_i16]
    sparserange.add(-39_i16..-35_i16)
    expect(sparserange.ranges).to eq [-39_i16..-35_i16, -25_i16..-25_i16, -20_i16..-10_i16, -5_i16..20_i16, 25_i16..25_i16, 27_i16..28_i16, 30_i16..40_i16, 45_i16..59_i16]
    sparserange.add(-33_i16..-27_i16)
    expect(sparserange.ranges).to eq [-39_i16..-35_i16, -33_i16..-27_i16, -25_i16..-25_i16, -20_i16..-10_i16, -5_i16..20_i16, 25_i16..25_i16, 27_i16..28_i16, 30_i16..40_i16, 45_i16..59_i16]
  end
  it "sorts the ranges" do
    sparserange = SparseRange(Int16).new list: [1_i16..10_i16, -19_i16..-9_i16, 21_i16..30_i16], assert: false
    expect(sparserange.ranges).to eq [-19_i16..-9_i16, 1_i16..10_i16, 21_i16..30_i16]
  end
  it "can be created from a string" do
    sparserange = SparseRange(Int16).new(list: "1,3,5")
    expect(sparserange.ranges).to eq [1_i16..1_i16, 3_i16..3_i16, 5_i16..5_i16]
    sparserange = SparseRange(Int16).new(list: "[1,3,5]")
    expect(sparserange.ranges).to eq [1_i16..1_i16, 3_i16..3_i16, 5_i16..5_i16]
    sparserange = SparseRange(Int16).new(list: "[1..3,5]")
    expect(sparserange.ranges).to eq [1_i16..3_i16, 5_i16..5_i16]
  end
  it "iterates the excluded values" do
    sparserange = SparseRange(Int16).new(list: "1,3,5")
    result = [] of Int16
    sparserange.each_excluded(start_at: 0, end_at: 9) do |num|
      result << num
    end
    expect(result).to eq [0, 2, 4, 6, 7, 8, 9] of Int16
  end
end
