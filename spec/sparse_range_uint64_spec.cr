require "./spec_helper"

describe SparseRange(UInt64) do
  it "can be created empty" do
    sparserange = SparseRange(UInt64).new
    sparserange.should be_a SparseRange(UInt64)
    sparserange.ranges.size.should eq 0
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange(UInt64).new list: [1_u64..10_u64, 21_u64..30_u64]
    sparserange.should be_a SparseRange(UInt64)
    sparserange.ranges.size.should eq 2
  end
  sparserange = SparseRange(UInt64).new list: [10_u64..19_u64, 30_u64..39_u64]
  it "calculates the min/max correctly" do
    sparserange.should be_a SparseRange(UInt64)
    sparserange.min.should eq 10
    sparserange.max.should eq 39
  end
  it "adds integers" do
    sparserange.add 40_u64
    sparserange.ranges.should eq [10_u64..19_u64, 30_u64..40_u64]
    sparserange.add 20_u64
    sparserange.ranges.should eq [10_u64..20_u64, 30_u64..40_u64]
    sparserange.add 45_u64
    sparserange.ranges.should eq [10_u64..20_u64, 30_u64..40_u64, 45_u64..45_u64]
    sparserange.add 25_u64
    sparserange.ranges.should eq [10_u64..20_u64, 25_u64..25_u64, 30_u64..40_u64, 45_u64..45_u64]
    sparserange.add 15_u64
    sparserange.ranges.should eq [10_u64..20_u64, 25_u64..25_u64, 30_u64..40_u64, 45_u64..45_u64]
  end
  it "adds ranges" do
    sparserange.add 27_u64..28_u64
    sparserange.ranges.should eq [10_u64..20_u64, 25_u64..25_u64, 27_u64..28_u64, 30_u64..40_u64, 45_u64..45_u64]
    sparserange.add 50_u64..59_u64
    sparserange.ranges.should eq [10_u64..20_u64, 25_u64..25_u64, 27_u64..28_u64, 30_u64..40_u64, 45_u64..45_u64, 50_u64..59_u64]
    sparserange.add 45_u64..50_u64
    sparserange.ranges.should eq [10_u64..20_u64, 25_u64..25_u64, 27_u64..28_u64, 30_u64..40_u64, 45_u64..59_u64]
    sparserange.add 0_u64..10_u64
    sparserange.ranges.should eq [0_u64..20_u64, 25_u64..25_u64, 27_u64..28_u64, 30_u64..40_u64, 45_u64..59_u64]
  end
  it "sorts the ranges" do
    sparserange = SparseRange(UInt64).new list: [11_u64..20_u64, 1_u64..9_u64, 23_u64..30_u64], assert: false
    sparserange.ranges.should eq [1_u64..9_u64, 11_u64..20_u64, 23_u64..30_u64]
  end
  it "can be created from a string" do
    sparserange = SparseRange(UInt64).new(list: "1,3,5")
    sparserange.ranges.should eq [1_u64..1_u64, 3_u64..3_u64, 5_u64..5_u64]
  end
  it "can invert the ranges" do
    sparserange = SparseRange(UInt64).new(list: "1,3,5")
    result = [] of UInt64
    sparserange.each_excluded(start_at: 0, end_at: 9) do |num|
      result << num
    end
    result.should eq [0, 2, 4, 6, 7, 8, 9] of UInt64
  end
end
