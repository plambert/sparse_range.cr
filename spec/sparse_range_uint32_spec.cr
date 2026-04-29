require "./spec_helper"

describe SparseRange(UInt32) do
  it "can be created empty" do
    sparserange = SparseRange(UInt32).new
    sparserange.should be_a SparseRange(UInt32)
    sparserange.ranges.size.should eq 0
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange(UInt32).new list: [1_u32..10_u32, 21_u32..30_u32]
    sparserange.should be_a SparseRange(UInt32)
    sparserange.ranges.size.should eq 2
  end
  sparserange = SparseRange(UInt32).new list: [10_u32..19_u32, 30_u32..39_u32]
  it "calculates the min/max correctly" do
    sparserange.should be_a SparseRange(UInt32)
    sparserange.min.should eq 10
    sparserange.max.should eq 39
  end
  it "adds integers" do
    sparserange.add 40_u32
    sparserange.ranges.should eq [10_u32..19_u32, 30_u32..40_u32]
    sparserange.add 20_u32
    sparserange.ranges.should eq [10_u32..20_u32, 30_u32..40_u32]
    sparserange.add 45_u32
    sparserange.ranges.should eq [10_u32..20_u32, 30_u32..40_u32, 45_u32..45_u32]
    sparserange.add 25_u32
    sparserange.ranges.should eq [10_u32..20_u32, 25_u32..25_u32, 30_u32..40_u32, 45_u32..45_u32]
    sparserange.add 15_u32
    sparserange.ranges.should eq [10_u32..20_u32, 25_u32..25_u32, 30_u32..40_u32, 45_u32..45_u32]
  end
  it "adds ranges" do
    sparserange.add 27_u32..28_u32
    sparserange.ranges.should eq [10_u32..20_u32, 25_u32..25_u32, 27_u32..28_u32, 30_u32..40_u32, 45_u32..45_u32]
    sparserange.add 50_u32..59_u32
    sparserange.ranges.should eq [10_u32..20_u32, 25_u32..25_u32, 27_u32..28_u32, 30_u32..40_u32, 45_u32..45_u32, 50_u32..59_u32]
    sparserange.add 45_u32..50_u32
    sparserange.ranges.should eq [10_u32..20_u32, 25_u32..25_u32, 27_u32..28_u32, 30_u32..40_u32, 45_u32..59_u32]
    sparserange.add 0_u32..10_u32
    sparserange.ranges.should eq [0_u32..20_u32, 25_u32..25_u32, 27_u32..28_u32, 30_u32..40_u32, 45_u32..59_u32]
  end
  it "sorts the ranges" do
    sparserange = SparseRange(UInt32).new list: [11_u32..20_u32, 1_u32..9_u32, 23_u32..30_u32], assert: false
    sparserange.ranges.should eq [1_u32..9_u32, 11_u32..20_u32, 23_u32..30_u32]
  end
  it "can be created from a string" do
    sparserange = SparseRange(UInt32).new(list: "1,3,5")
    sparserange.ranges.should eq [1_u32..1_u32, 3_u32..3_u32, 5_u32..5_u32]
  end
  it "can invert the ranges" do
    sparserange = SparseRange(UInt32).new(list: "1,3,5")
    result = [] of UInt32
    sparserange.each_excluded(start_at: 0, end_at: 9) do |num|
      result << num
    end
    result.should eq [0, 2, 4, 6, 7, 8, 9] of UInt32
  end
end
