require "./spec_helper"

Spectator.describe SparseRange(UInt8) do
  let(sparserange) { SparseRange(UInt8).new list: [10_u8..19_u8, 30_u8..39_u8] }

  it "can be created empty" do
    sparserange = SparseRange(UInt8).new
    expect(sparserange.ranges.size).to eq 0
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange(UInt8).new list: [1_u8..10_u8, 21_u8..30_u8]
    expect(sparserange.ranges.size).to eq 2
  end
  it "calculates the min/max correctly" do
    expect(sparserange.min).to eq 10
    expect(sparserange.max).to eq 39
  end
  it "adds integers" do
    sparserange.add 40_u8
    expect(sparserange.ranges).to eq [10_u8..19_u8, 30_u8..40_u8]
    sparserange.add 20_u8
    expect(sparserange.ranges).to eq [10_u8..20_u8, 30_u8..40_u8]
    sparserange.add 45_u8
    expect(sparserange.ranges).to eq [10_u8..20_u8, 30_u8..40_u8, 45_u8..45_u8]
    sparserange.add 25_u8
    expect(sparserange.ranges).to eq [10_u8..20_u8, 25_u8..25_u8, 30_u8..40_u8, 45_u8..45_u8]
    sparserange.add 15_u8
    expect(sparserange.ranges).to eq [10_u8..20_u8, 25_u8..25_u8, 30_u8..40_u8, 45_u8..45_u8]
  end
  it "adds ranges" do
    sparserange = SparseRange(UInt8).new list: [10_u8..20_u8, 25_u8..25_u8, 30_u8..40_u8, 45_u8..45_u8]
    sparserange.add 27_u8..28_u8
    expect(sparserange.ranges).to eq [10_u8..20_u8, 25_u8..25_u8, 27_u8..28_u8, 30_u8..40_u8, 45_u8..45_u8]
    sparserange.add 50_u8..59_u8
    expect(sparserange.ranges).to eq [10_u8..20_u8, 25_u8..25_u8, 27_u8..28_u8, 30_u8..40_u8, 45_u8..45_u8, 50_u8..59_u8]
    sparserange.add 45_u8..50_u8
    expect(sparserange.ranges).to eq [10_u8..20_u8, 25_u8..25_u8, 27_u8..28_u8, 30_u8..40_u8, 45_u8..59_u8]
    sparserange.add 0_u8..10_u8
    expect(sparserange.ranges).to eq [0_u8..20_u8, 25_u8..25_u8, 27_u8..28_u8, 30_u8..40_u8, 45_u8..59_u8]
  end
  it "sorts the ranges" do
    sparserange = SparseRange(UInt8).new list: [11_u8..20_u8, 1_u8..9_u8, 23_u8..30_u8], assert: false
    expect(sparserange.ranges).to eq [1_u8..9_u8, 11_u8..20_u8, 23_u8..30_u8]
  end
  it "can be created from a string" do
    sparserange = SparseRange(UInt8).new(list: "1,3,5")
    expect(sparserange.ranges).to eq [1_u8..1_u8, 3_u8..3_u8, 5_u8..5_u8]
  end
  it "iterates the excluded values" do
    sparserange = SparseRange(UInt8).new(list: "1,3,5")
    result = [] of UInt8
    sparserange.each_excluded(start_at: 0, end_at: 9) do |num|
      result << num
    end
    expect(result).to eq [0, 2, 4, 6, 7, 8, 9] of UInt8
  end
end
