require "./spec_helper"

describe SparseRange(UInt16) do
  it "can be created empty" do
    sparserange = SparseRange(UInt16).new
    sparserange.should be_a SparseRange(UInt16)
    sparserange.ranges.size.should eq 0
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange(UInt16).new list: [1_u16..10_u16, 21_u16..30_u16]
    sparserange.should be_a SparseRange(UInt16)
    sparserange.ranges.size.should eq 2
  end
  sparserange = SparseRange(UInt16).new list: [10_u16..19_u16, 30_u16..39_u16]
  it "calculates the min/max correctly" do
    sparserange.should be_a SparseRange(UInt16)
    sparserange.min.should eq 10
    sparserange.max.should eq 39
  end
  it "adds integers" do
    sparserange.add 40_u16
    sparserange.ranges.should eq [10_u16..19_u16, 30_u16..40_u16]
    sparserange.add 20_u16
    sparserange.ranges.should eq [10_u16..20_u16, 30_u16..40_u16]
    sparserange.add 45_u16
    sparserange.ranges.should eq [10_u16..20_u16, 30_u16..40_u16, 45_u16..45_u16]
    sparserange.add 25_u16
    sparserange.ranges.should eq [10_u16..20_u16, 25_u16..25_u16, 30_u16..40_u16, 45_u16..45_u16]
    sparserange.add 15_u16
    sparserange.ranges.should eq [10_u16..20_u16, 25_u16..25_u16, 30_u16..40_u16, 45_u16..45_u16]
  end
  it "adds ranges" do
    sparserange.add 27_u16..28_u16
    sparserange.ranges.should eq [10_u16..20_u16, 25_u16..25_u16, 27_u16..28_u16, 30_u16..40_u16, 45_u16..45_u16]
    sparserange.add 50_u16..59_u16
    sparserange.ranges.should eq [10_u16..20_u16, 25_u16..25_u16, 27_u16..28_u16, 30_u16..40_u16, 45_u16..45_u16, 50_u16..59_u16]
    sparserange.add 45_u16..50_u16
    sparserange.ranges.should eq [10_u16..20_u16, 25_u16..25_u16, 27_u16..28_u16, 30_u16..40_u16, 45_u16..59_u16]
    sparserange.add 0_u16..10_u16
    sparserange.ranges.should eq [0_u16..20_u16, 25_u16..25_u16, 27_u16..28_u16, 30_u16..40_u16, 45_u16..59_u16]
  end
  it "sorts the ranges" do
    sparserange = SparseRange(UInt16).new list: [11_u16..20_u16, 1_u16..9_u16, 23_u16..30_u16], assert: false
    sparserange.ranges.should eq [1_u16..9_u16, 11_u16..20_u16, 23_u16..30_u16]
  end
  it "can be created from a string" do
    sparserange = SparseRange(UInt16).new(list: "1,3,5")
    sparserange.ranges.should eq [1_u16..1_u16, 3_u16..3_u16, 5_u16..5_u16]
  end
  it "can invert the ranges" do
    sparserange = SparseRange(UInt16).new(list: "1,3,5")
    result = [] of UInt16
    sparserange.each_excluded(start_at: 0, end_at: 9) do |num|
      result << num
    end
    result.should eq [0, 2, 4, 6, 7, 8, 9] of UInt16
  end
end
