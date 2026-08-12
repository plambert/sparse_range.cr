require "./spec_helper"

Spectator.describe SparseRange(Int8) do
  let(sparserange) { SparseRange(Int8).new list: [-19_i8..-10_i8, 10_i8..19_i8, 30_i8..39_i8] }

  it "can be created empty" do
    sparserange = SparseRange(Int8).new
    expect(sparserange).to be_a SparseRange(Int8)
    expect(sparserange.ranges.size).to eq 0
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange(Int8).new list: [1_i8..10_i8, 21_i8..30_i8]
    expect(sparserange).to be_a SparseRange(Int8)
    expect(sparserange.ranges.size).to eq 2
  end
  it "calculates the min/max correctly" do
    expect(sparserange.min).to eq -19
    expect(sparserange.max).to eq 39
  end
  it "adds integers" do
    sparserange.add 40
    expect(sparserange.ranges).to eq [-19_i8..-10_i8, 10_i8..19_i8, 30_i8..40_i8]
    sparserange.add 20
    expect(sparserange.ranges).to eq [-19_i8..-10_i8, 10_i8..20_i8, 30_i8..40_i8]
    sparserange.add -20
    expect(sparserange.ranges).to eq [-20_i8..-10_i8, 10_i8..20_i8, 30_i8..40_i8]
    sparserange.add 45
    expect(sparserange.ranges).to eq [-20_i8..-10_i8, 10_i8..20_i8, 30_i8..40_i8, 45_i8..45_i8]
    sparserange.add 25
    expect(sparserange.ranges).to eq [-20_i8..-10_i8, 10_i8..20_i8, 25_i8..25_i8, 30_i8..40_i8, 45_i8..45_i8]
    sparserange.add 15
    expect(sparserange.ranges).to eq [-20_i8..-10_i8, 10_i8..20_i8, 25_i8..25_i8, 30_i8..40_i8, 45_i8..45_i8]
    sparserange.add -5
    expect(sparserange.ranges).to eq [-20_i8..-10_i8, -5_i8..-5_i8, 10_i8..20_i8, 25_i8..25_i8, 30_i8..40_i8, 45_i8..45_i8]
    sparserange.add -25
    expect(sparserange.ranges).to eq [-25_i8..-25_i8, -20_i8..-10_i8, -5_i8..-5_i8, 10_i8..20_i8, 25_i8..25_i8, 30_i8..40_i8, 45_i8..45_i8]
  end
  it "adds ranges" do
    sparserange = SparseRange(Int8).new list: [-25_i8..-25_i8, -20_i8..-10_i8, -5_i8..-5_i8, 10_i8..20_i8, 25_i8..25_i8, 30_i8..40_i8, 45_i8..45_i8]
    sparserange.add(27_i8..28_i8)
    expect(sparserange.ranges).to eq [-25_i8..-25_i8, -20_i8..-10_i8, -5_i8..-5_i8, 10_i8..20_i8, 25_i8..25_i8, 27_i8..28_i8, 30_i8..40_i8, 45_i8..45_i8]
    sparserange.add(50_i8..59_i8)
    expect(sparserange.ranges).to eq [-25_i8..-25_i8, -20_i8..-10_i8, -5_i8..-5_i8, 10_i8..20_i8, 25_i8..25_i8, 27_i8..28_i8, 30_i8..40_i8, 45_i8..45_i8, 50_i8..59_i8]
    sparserange.add(45_i8..50_i8)
    expect(sparserange.ranges).to eq [-25_i8..-25_i8, -20_i8..-10_i8, -5_i8..-5_i8, 10_i8..20_i8, 25_i8..25_i8, 27_i8..28_i8, 30_i8..40_i8, 45_i8..59_i8]
    sparserange.add(-5_i8..10_i8)
    expect(sparserange.ranges).to eq [-25_i8..-25_i8, -20_i8..-10_i8, -5_i8..20_i8, 25_i8..25_i8, 27_i8..28_i8, 30_i8..40_i8, 45_i8..59_i8]
    sparserange.add(-39_i8..-35_i8)
    expect(sparserange.ranges).to eq [-39_i8..-35_i8, -25_i8..-25_i8, -20_i8..-10_i8, -5_i8..20_i8, 25_i8..25_i8, 27_i8..28_i8, 30_i8..40_i8, 45_i8..59_i8]
    sparserange.add(-33_i8..-27_i8)
    expect(sparserange.ranges).to eq [-39_i8..-35_i8, -33_i8..-27_i8, -25_i8..-25_i8, -20_i8..-10_i8, -5_i8..20_i8, 25_i8..25_i8, 27_i8..28_i8, 30_i8..40_i8, 45_i8..59_i8]
  end
  it "sorts the ranges" do
    sparserange = SparseRange(Int8).new list: [1_i8..10_i8, -19_i8..-9_i8, 21_i8..30_i8], assert: false
    expect(sparserange.ranges).to eq [-19_i8..-9_i8, 1_i8..10_i8, 21_i8..30_i8]
  end
  it "can be created from a string" do
    sparserange = SparseRange(Int8).new(list: "1,3,5")
    expect(sparserange.ranges).to eq [1_i8..1_i8, 3_i8..3_i8, 5_i8..5_i8]
  end
  it "iterates the excluded values" do
    sparserange = SparseRange(Int8).new(list: "1,3,5")
    result = [] of Int8
    sparserange.each_excluded(start_at: 0, end_at: 9) do |num|
      result << num
    end
    expect(result).to eq [0, 2, 4, 6, 7, 8, 9] of Int8
  end
end
