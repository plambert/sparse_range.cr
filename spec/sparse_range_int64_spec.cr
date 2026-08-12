require "./spec_helper"

Spectator.describe SparseRange(Int64) do
  let(sparserange) { SparseRange(Int64).new list: [-19_i64..-10_i64, 10_i64..19_i64, 30_i64..39_i64] }

  it "can be created empty" do
    sparserange = SparseRange(Int64).new
    expect(sparserange.ranges.size).to eq 0
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange(Int64).new list: [1_i64..10_i64, 21_i64..30_i64]
    expect(sparserange.ranges.size).to eq 2
  end
  it "calculates the min/max correctly" do
    expect(sparserange.min).to eq -19
    expect(sparserange.max).to eq 39
  end
  it "adds integers" do
    sparserange.add 40_i64
    expect(sparserange.ranges).to eq [-19_i64..-10_i64, 10_i64..19_i64, 30_i64..40_i64]
    sparserange.add 20_i64
    expect(sparserange.ranges).to eq [-19_i64..-10_i64, 10_i64..20_i64, 30_i64..40_i64]
    sparserange.add -20_i64
    expect(sparserange.ranges).to eq [-20_i64..-10_i64, 10_i64..20_i64, 30_i64..40_i64]
    sparserange.add 45_i64
    expect(sparserange.ranges).to eq [-20_i64..-10_i64, 10_i64..20_i64, 30_i64..40_i64, 45_i64..45_i64]
    sparserange.add 25_i64
    expect(sparserange.ranges).to eq [-20_i64..-10_i64, 10_i64..20_i64, 25_i64..25_i64, 30_i64..40_i64, 45_i64..45_i64]
    sparserange.add 15_i64
    expect(sparserange.ranges).to eq [-20_i64..-10_i64, 10_i64..20_i64, 25_i64..25_i64, 30_i64..40_i64, 45_i64..45_i64]
    sparserange.add -5_i64
    expect(sparserange.ranges).to eq [-20_i64..-10_i64, -5_i64..-5_i64, 10_i64..20_i64, 25_i64..25_i64, 30_i64..40_i64, 45_i64..45_i64]
    sparserange.add -25_i64
    expect(sparserange.ranges).to eq [-25_i64..-25_i64, -20_i64..-10_i64, -5_i64..-5_i64, 10_i64..20_i64, 25_i64..25_i64, 30_i64..40_i64, 45_i64..45_i64]
  end
  it "adds ranges" do
    sparserange = SparseRange(Int64).new list: [-25_i64..-25_i64, -20_i64..-10_i64, -5_i64..-5_i64, 10_i64..20_i64, 25_i64..25_i64, 30_i64..40_i64, 45_i64..45_i64]
    sparserange.add 27_i64..28_i64
    expect(sparserange.ranges).to eq [-25_i64..-25_i64, -20_i64..-10_i64, -5_i64..-5_i64, 10_i64..20_i64, 25_i64..25_i64, 27_i64..28_i64, 30_i64..40_i64, 45_i64..45_i64]
    sparserange.add 50_i64..59_i64
    expect(sparserange.ranges).to eq [-25_i64..-25_i64, -20_i64..-10_i64, -5_i64..-5_i64, 10_i64..20_i64, 25_i64..25_i64, 27_i64..28_i64, 30_i64..40_i64, 45_i64..45_i64, 50_i64..59_i64]
    sparserange.add 45_i64..50_i64
    expect(sparserange.ranges).to eq [-25_i64..-25_i64, -20_i64..-10_i64, -5_i64..-5_i64, 10_i64..20_i64, 25_i64..25_i64, 27_i64..28_i64, 30_i64..40_i64, 45_i64..59_i64]
    sparserange.add -5_i64..10_i64
    expect(sparserange.ranges).to eq [-25_i64..-25_i64, -20_i64..-10_i64, -5_i64..20_i64, 25_i64..25_i64, 27_i64..28_i64, 30_i64..40_i64, 45_i64..59_i64]
    sparserange.add -39_i64..-35_i64
    expect(sparserange.ranges).to eq [-39_i64..-35_i64, -25_i64..-25_i64, -20_i64..-10_i64, -5_i64..20_i64, 25_i64..25_i64, 27_i64..28_i64, 30_i64..40_i64, 45_i64..59_i64]
    sparserange.add -33_i64..-27_i64
    expect(sparserange.ranges).to eq [-39_i64..-35_i64, -33_i64..-27_i64, -25_i64..-25_i64, -20_i64..-10_i64, -5_i64..20_i64, 25_i64..25_i64, 27_i64..28_i64, 30_i64..40_i64, 45_i64..59_i64]
  end
  it "sorts the ranges" do
    sparserange = SparseRange(Int64).new list: [1_i64..10_i64, -19_i64..-9_i64, 21_i64..30_i64], assert: false
    expect(sparserange.ranges).to eq [-19_i64..-9_i64, 1_i64..10_i64, 21_i64..30_i64]
  end
  it "can be created from a string" do
    sparserange = SparseRange(Int64).new(list: "1,3,5")
    expect(sparserange.ranges).to eq [1_i64..1_i64, 3_i64..3_i64, 5_i64..5_i64]
  end
  it "iterates the excluded values" do
    sparserange = SparseRange(Int64).new(list: "1,3,5")
    result = [] of Int64
    sparserange.each_excluded(start_at: 0, end_at: 9) do |num|
      result << num
    end
    expect(result).to eq [0, 2, 4, 6, 7, 8, 9] of Int64
  end
end
