require "./spec_helper"

describe SparseRange(Int8) do
  it "can be created empty" do
    sparserange = SparseRange(Int8).new
    sparserange.should be_a SparseRange(Int8)
    sparserange.ranges.size.should eq 0
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange(Int8).new list: [1_i8..10_i8, 21_i8..30_i8]
    sparserange.should be_a SparseRange(Int8)
    sparserange.ranges.size.should eq 2
  end
  sparserange = SparseRange(Int8).new list: [-19_i8..-10_i8, 10_i8..19_i8, 30_i8..39_i8]
  it "calculates the min/max correctly" do
    sparserange.should be_a SparseRange(Int8)
    sparserange.min.should eq -19
    sparserange.max.should eq 39
  end
  it "adds integers" do
    sparserange.should be_a SparseRange(Int8)
    sparserange.add 40
    sparserange.ranges.should eq [-19_i8..-10_i8, 10_i8..19_i8, 30_i8..40_i8]
    sparserange.add 20
    sparserange.ranges.should eq [-19_i8..-10_i8, 10_i8..20_i8, 30_i8..40_i8]
    sparserange.add -20
    sparserange.ranges.should eq [-20_i8..-10_i8, 10_i8..20_i8, 30_i8..40_i8]
    sparserange.add 45
    sparserange.ranges.should eq [-20_i8..-10_i8, 10_i8..20_i8, 30_i8..40_i8, 45_i8..45_i8]
    sparserange.add 25
    sparserange.ranges.should eq [-20_i8..-10_i8, 10_i8..20_i8, 25_i8..25_i8, 30_i8..40_i8, 45_i8..45_i8]
    sparserange.add 15
    sparserange.ranges.should eq [-20_i8..-10_i8, 10_i8..20_i8, 25_i8..25_i8, 30_i8..40_i8, 45_i8..45_i8]
    sparserange.add -5
    sparserange.ranges.should eq [-20_i8..-10_i8, -5_i8..-5_i8, 10_i8..20_i8, 25_i8..25_i8, 30_i8..40_i8, 45_i8..45_i8]
    sparserange.add -25
    sparserange.ranges.should eq [-25_i8..-25_i8, -20_i8..-10_i8, -5_i8..-5_i8, 10_i8..20_i8, 25_i8..25_i8, 30_i8..40_i8, 45_i8..45_i8]
  end
  it "adds ranges" do
    sparserange.should be_a SparseRange(Int8)
    sparserange.add(27_i8..28_i8)
    sparserange.ranges.should eq [-25_i8..-25_i8, -20_i8..-10_i8, -5_i8..-5_i8, 10_i8..20_i8, 25_i8..25_i8, 27_i8..28_i8, 30_i8..40_i8, 45_i8..45_i8]
    sparserange.add(50_i8..59_i8)
    sparserange.ranges.should eq [-25_i8..-25_i8, -20_i8..-10_i8, -5_i8..-5_i8, 10_i8..20_i8, 25_i8..25_i8, 27_i8..28_i8, 30_i8..40_i8, 45_i8..45_i8, 50_i8..59_i8]
    sparserange.add(45_i8..50_i8)
    sparserange.ranges.should eq [-25_i8..-25_i8, -20_i8..-10_i8, -5_i8..-5_i8, 10_i8..20_i8, 25_i8..25_i8, 27_i8..28_i8, 30_i8..40_i8, 45_i8..59_i8]
    sparserange.add(-5_i8..10_i8)
    sparserange.ranges.should eq [-25_i8..-25_i8, -20_i8..-10_i8, -5_i8..20_i8, 25_i8..25_i8, 27_i8..28_i8, 30_i8..40_i8, 45_i8..59_i8]
    sparserange.add(-39_i8..-35_i8)
    sparserange.ranges.should eq [-39_i8..-35_i8, -25_i8..-25_i8, -20_i8..-10_i8, -5_i8..20_i8, 25_i8..25_i8, 27_i8..28_i8, 30_i8..40_i8, 45_i8..59_i8]
    sparserange.add(-33_i8..-27_i8)
    sparserange.ranges.should eq [-39_i8..-35_i8, -33_i8..-27_i8, -25_i8..-25_i8, -20_i8..-10_i8, -5_i8..20_i8, 25_i8..25_i8, 27_i8..28_i8, 30_i8..40_i8, 45_i8..59_i8]
  end
  it "sorts the ranges" do
    sparserange = SparseRange(Int8).new list: [1_i8..10_i8, -19_i8..-9_i8, 21_i8..30_i8], assert: false
    sparserange.ranges.should eq [-19_i8..-9_i8, 1_i8..10_i8, 21_i8..30_i8]
  end
  it "can be created from a string" do
    sparserange = SparseRange(Int8).new(list: "1,3,5")
    sparserange.ranges.should eq [1_i8..1_i8, 3_i8..3_i8, 5_i8..5_i8]
  end
  it "can invert the ranges" do
    sparserange = SparseRange(Int8).new(list: "1,3,5")
    result = [] of Int8
    sparserange.each_excluded(start_at: 0, end_at: 9) do |num|
      result << num
    end
    result.should eq [0, 2, 4, 6, 7, 8, 9] of Int8
  end
end
