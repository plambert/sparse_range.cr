require "./spec_helper"

describe SparseRange(UInt8) do
  it "can be created empty" do
    sparserange = SparseRange(UInt8).new
    sparserange.should be_a SparseRange(UInt8)
    sparserange.ranges.size.should eq 0
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange(UInt8).new list: [1_u8..10_u8, 21_u8..30_u8]
    sparserange.should be_a SparseRange(UInt8)
    sparserange.ranges.size.should eq 2
  end
  sparserange = SparseRange(UInt8).new list: [10_u8..19_u8, 30_u8..39_u8]
  it "calculates the min/max correctly" do
    sparserange.should be_a SparseRange(UInt8)
    sparserange.min.should eq 10
    sparserange.max.should eq 39
  end
  it "adds integers" do
    sparserange.add 40_u8
    sparserange.ranges.should eq [10_u8..19_u8, 30_u8..40_u8]
    sparserange.add 20_u8
    sparserange.ranges.should eq [10_u8..20_u8, 30_u8..40_u8]
    sparserange.add 45_u8
    sparserange.ranges.should eq [10_u8..20_u8, 30_u8..40_u8, 45_u8..45_u8]
    sparserange.add 25_u8
    sparserange.ranges.should eq [10_u8..20_u8, 25_u8..25_u8, 30_u8..40_u8, 45_u8..45_u8]
    sparserange.add 15_u8
    sparserange.ranges.should eq [10_u8..20_u8, 25_u8..25_u8, 30_u8..40_u8, 45_u8..45_u8]
  end
  it "adds ranges" do
    sparserange.add 27_u8..28_u8
    sparserange.ranges.should eq [10_u8..20_u8, 25_u8..25_u8, 27_u8..28_u8, 30_u8..40_u8, 45_u8..45_u8]
    sparserange.add 50_u8..59_u8
    sparserange.ranges.should eq [10_u8..20_u8, 25_u8..25_u8, 27_u8..28_u8, 30_u8..40_u8, 45_u8..45_u8, 50_u8..59_u8]
    sparserange.add 45_u8..50_u8
    sparserange.ranges.should eq [10_u8..20_u8, 25_u8..25_u8, 27_u8..28_u8, 30_u8..40_u8, 45_u8..59_u8]
    sparserange.add 0_u8..10_u8
    sparserange.ranges.should eq [0_u8..20_u8, 25_u8..25_u8, 27_u8..28_u8, 30_u8..40_u8, 45_u8..59_u8]
  end
  it "sorts the ranges" do
    sparserange = SparseRange(UInt8).new list: [11_u8..20_u8, 1_u8..9_u8, 23_u8..30_u8], assert: false
    sparserange.ranges.should eq [1_u8..9_u8, 11_u8..20_u8, 23_u8..30_u8]
  end
  it "can be created from a string" do
    sparserange = SparseRange(UInt8).new(list: "1,3,5")
    sparserange.ranges.should eq [1_u8..1_u8, 3_u8..3_u8, 5_u8..5_u8]
  end
  it "can invert the ranges" do
    sparserange = SparseRange(UInt8).new(list: "1,3,5")
    result = [] of UInt8
    sparserange.each_excluded(start_at: 0, end_at: 9) do |num|
      result << num
    end
    result.should eq [0, 2, 4, 6, 7, 8, 9] of UInt8
  end
end
