require "./spec_helper"

Spectator.describe SparseRange(UInt32) do
  let(sparserange) { SparseRange(UInt32).new list: [10_u32..19_u32, 30_u32..39_u32] }

  it "can be created empty" do
    sparserange = SparseRange(UInt32).new
    expect(sparserange.ranges.size).to eq 0
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange(UInt32).new list: [1_u32..10_u32, 21_u32..30_u32]
    expect(sparserange.ranges.size).to eq 2
  end
  it "calculates the min/max correctly" do
    expect(sparserange.min).to eq 10
    expect(sparserange.max).to eq 39
  end
  it "adds integers" do
    sparserange.add 40_u32
    expect(sparserange.ranges).to eq [10_u32..19_u32, 30_u32..40_u32]
    sparserange.add 20_u32
    expect(sparserange.ranges).to eq [10_u32..20_u32, 30_u32..40_u32]
    sparserange.add 45_u32
    expect(sparserange.ranges).to eq [10_u32..20_u32, 30_u32..40_u32, 45_u32..45_u32]
    sparserange.add 25_u32
    expect(sparserange.ranges).to eq [10_u32..20_u32, 25_u32..25_u32, 30_u32..40_u32, 45_u32..45_u32]
    sparserange.add 15_u32
    expect(sparserange.ranges).to eq [10_u32..20_u32, 25_u32..25_u32, 30_u32..40_u32, 45_u32..45_u32]
  end
  it "adds ranges" do
    sparserange = SparseRange(UInt32).new list: [10_u32..20_u32, 25_u32..25_u32, 30_u32..40_u32, 45_u32..45_u32]
    sparserange.add 27_u32..28_u32
    expect(sparserange.ranges).to eq [10_u32..20_u32, 25_u32..25_u32, 27_u32..28_u32, 30_u32..40_u32, 45_u32..45_u32]
    sparserange.add 50_u32..59_u32
    expect(sparserange.ranges).to eq [10_u32..20_u32, 25_u32..25_u32, 27_u32..28_u32, 30_u32..40_u32, 45_u32..45_u32, 50_u32..59_u32]
    sparserange.add 45_u32..50_u32
    expect(sparserange.ranges).to eq [10_u32..20_u32, 25_u32..25_u32, 27_u32..28_u32, 30_u32..40_u32, 45_u32..59_u32]
    sparserange.add 0_u32..10_u32
    expect(sparserange.ranges).to eq [0_u32..20_u32, 25_u32..25_u32, 27_u32..28_u32, 30_u32..40_u32, 45_u32..59_u32]
  end
  it "sorts the ranges" do
    sparserange = SparseRange(UInt32).new list: [11_u32..20_u32, 1_u32..9_u32, 23_u32..30_u32], assert: false
    expect(sparserange.ranges).to eq [1_u32..9_u32, 11_u32..20_u32, 23_u32..30_u32]
  end
  it "can be created from a string" do
    sparserange = SparseRange(UInt32).new(list: "1,3,5")
    expect(sparserange.ranges).to eq [1_u32..1_u32, 3_u32..3_u32, 5_u32..5_u32]
  end
  it "iterates the excluded values" do
    sparserange = SparseRange(UInt32).new(list: "1,3,5")
    result = [] of UInt32
    sparserange.each_excluded(start_at: 0, end_at: 9) do |num|
      result << num
    end
    expect(result).to eq [0, 2, 4, 6, 7, 8, 9] of UInt32
  end
end
