require "./spec_helper"

describe SparseRange(Int16) do
  it "can be created empty" do
    sparserange = SparseRange(Int16).new
    sparserange.should be_a SparseRange(Int16)
    sparserange.ranges.size.should eq 0
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange(Int16).new list: [1_i16..10_i16, 21_i16..30_i16]
    sparserange.should be_a SparseRange(Int16)
    sparserange.ranges.size.should eq 2
  end
  sparserange = SparseRange(Int16).new list: [-19_i16..-10_i16, 10_i16..19_i16, 30_i16..39_i16]
  it "calculates the min/max correctly" do
    sparserange.should be_a SparseRange(Int16)
    sparserange.min.should eq -19
    sparserange.max.should eq 39
  end
  it "adds integers" do
    sparserange.should be_a SparseRange(Int16)
    sparserange.add 40
    sparserange.ranges.should eq [-19_i16..-10_i16, 10_i16..19_i16, 30_i16..40_i16]
    sparserange.add 20
    sparserange.ranges.should eq [-19_i16..-10_i16, 10_i16..20_i16, 30_i16..40_i16]
    sparserange.add -20
    sparserange.ranges.should eq [-20_i16..-10_i16, 10_i16..20_i16, 30_i16..40_i16]
    sparserange.add 45
    sparserange.ranges.should eq [-20_i16..-10_i16, 10_i16..20_i16, 30_i16..40_i16, 45_i16..45_i16]
    sparserange.add 25
    sparserange.ranges.should eq [-20_i16..-10_i16, 10_i16..20_i16, 25_i16..25_i16, 30_i16..40_i16, 45_i16..45_i16]
    sparserange.add 15
    sparserange.ranges.should eq [-20_i16..-10_i16, 10_i16..20_i16, 25_i16..25_i16, 30_i16..40_i16, 45_i16..45_i16]
    sparserange.add -5
    sparserange.ranges.should eq [-20_i16..-10_i16, -5_i16..-5_i16, 10_i16..20_i16, 25_i16..25_i16, 30_i16..40_i16, 45_i16..45_i16]
    sparserange.add -25
    sparserange.ranges.should eq [-25_i16..-25_i16, -20_i16..-10_i16, -5_i16..-5_i16, 10_i16..20_i16, 25_i16..25_i16, 30_i16..40_i16, 45_i16..45_i16]
  end
  it "adds ranges" do
    sparserange.should be_a SparseRange(Int16)
    sparserange.add(27_i16..28_i16)
    sparserange.ranges.should eq [-25_i16..-25_i16, -20_i16..-10_i16, -5_i16..-5_i16, 10_i16..20_i16, 25_i16..25_i16, 27_i16..28_i16, 30_i16..40_i16, 45_i16..45_i16]
    sparserange.add(50_i16..59_i16)
    sparserange.ranges.should eq [-25_i16..-25_i16, -20_i16..-10_i16, -5_i16..-5_i16, 10_i16..20_i16, 25_i16..25_i16, 27_i16..28_i16, 30_i16..40_i16, 45_i16..45_i16, 50_i16..59_i16]
    sparserange.add(45_i16..50_i16)
    sparserange.ranges.should eq [-25_i16..-25_i16, -20_i16..-10_i16, -5_i16..-5_i16, 10_i16..20_i16, 25_i16..25_i16, 27_i16..28_i16, 30_i16..40_i16, 45_i16..59_i16]
    sparserange.add(-5_i16..10_i16)
    sparserange.ranges.should eq [-25_i16..-25_i16, -20_i16..-10_i16, -5_i16..20_i16, 25_i16..25_i16, 27_i16..28_i16, 30_i16..40_i16, 45_i16..59_i16]
    sparserange.add(-39_i16..-35_i16)
    sparserange.ranges.should eq [-39_i16..-35_i16, -25_i16..-25_i16, -20_i16..-10_i16, -5_i16..20_i16, 25_i16..25_i16, 27_i16..28_i16, 30_i16..40_i16, 45_i16..59_i16]
    sparserange.add(-33_i16..-27_i16)
    sparserange.ranges.should eq [-39_i16..-35_i16, -33_i16..-27_i16, -25_i16..-25_i16, -20_i16..-10_i16, -5_i16..20_i16, 25_i16..25_i16, 27_i16..28_i16, 30_i16..40_i16, 45_i16..59_i16]
  end
  it "sorts the ranges" do
    sparserange = SparseRange(Int16).new list: [1_i16..10_i16, -19_i16..-9_i16, 21_i16..30_i16], assert: false
    sparserange.ranges.should eq [-19_i16..-9_i16, 1_i16..10_i16, 21_i16..30_i16]
  end
  it "can be created from a string" do
    sparserange = SparseRange(Int16).new(list: "1,3,5")
    sparserange.ranges.should eq [1_i16..1_i16, 3_i16..3_i16, 5_i16..5_i16]
    sparserange = SparseRange(Int16).new(list: "[1,3,5]")
    sparserange.ranges.should eq [1_i16..1_i16, 3_i16..3_i16, 5_i16..5_i16]
    sparserange = SparseRange(Int16).new(list: "[1..3,5]")
    sparserange.ranges.should eq [1_i16..3_i16, 5_i16..5_i16]
  end
  it "can invert the ranges" do
    sparserange = SparseRange(Int16).new(list: "1,3,5")
    result = [] of Int16
    sparserange.each_excluded(start_at: 0, end_at: 9) do |num|
      result << num
    end
    result.should eq [0, 2, 4, 6, 7, 8, 9] of Int16
  end
end
