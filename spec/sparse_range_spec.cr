require "./spec_helper"

describe SparseRange(Int32) do
  it "can be created empty" do
    sparserange = SparseRange(Int32).new
    sparserange.should be_a SparseRange(Int32)
    sparserange.ranges.size.should eq 0
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange(Int32).new list: [1..10, 21..30]
    sparserange.should be_a SparseRange(Int32)
    sparserange.ranges.size.should eq 2
  end
  sparserange = SparseRange(Int32).new list: [-19..-10, 10..19, 30..39]
  it "calculates the min/max correctly" do
    # sparserange = SparseRange(Int32).new list: [1..10, 21..30]
    sparserange.should be_a SparseRange(Int32)
    sparserange.min.should eq -19
    sparserange.max.should eq 39
  end
  it "adds integers" do
    # sparserange = SparseRange(Int32).new list: [1..10, 21..30]
    sparserange.add 40
    sparserange.ranges.should eq [-19..-10, 10..19, 30..40]
    sparserange.add 20
    sparserange.ranges.should eq [-19..-10, 10..20, 30..40]
    sparserange.add -20
    sparserange.ranges.should eq [-20..-10, 10..20, 30..40]
    sparserange.add 45
    sparserange.ranges.should eq [-20..-10, 10..20, 30..40, 45..45]
    sparserange.add 25
    sparserange.ranges.should eq [-20..-10, 10..20, 25..25, 30..40, 45..45]
    sparserange.add 15
    sparserange.ranges.should eq [-20..-10, 10..20, 25..25, 30..40, 45..45]
    sparserange.add -5
    sparserange.ranges.should eq [-20..-10, -5..-5, 10..20, 25..25, 30..40, 45..45]
    sparserange.add -25
    sparserange.ranges.should eq [-25..-25, -20..-10, -5..-5, 10..20, 25..25, 30..40, 45..45]
  end
  it "adds ranges" do
    sparserange.add 27..28
    sparserange.ranges.should eq [-25..-25, -20..-10, -5..-5, 10..20, 25..25, 27..28, 30..40, 45..45]
    sparserange.add 50..59
    sparserange.ranges.should eq [-25..-25, -20..-10, -5..-5, 10..20, 25..25, 27..28, 30..40, 45..45, 50..59]
    sparserange.add 45..50
    sparserange.ranges.should eq [-25..-25, -20..-10, -5..-5, 10..20, 25..25, 27..28, 30..40, 45..59]
    sparserange.add -5..10
    sparserange.ranges.should eq [-25..-25, -20..-10, -5..20, 25..25, 27..28, 30..40, 45..59]
    sparserange.add -39..-35
    sparserange.ranges.should eq [-39..-35, -25..-25, -20..-10, -5..20, 25..25, 27..28, 30..40, 45..59]
    sparserange.add -33..-27
    sparserange.ranges.should eq [-39..-35, -33..-27, -25..-25, -20..-10, -5..20, 25..25, 27..28, 30..40, 45..59]
  end
  it "sorts the ranges" do
    sparserange = SparseRange(Int32).new list: [1..10, -19..-9, 21..30], assert: false
    sparserange.ranges.should eq [-19..-9, 1..10, 21..30]
  end
end

describe SparseRange(Int64) do
  it "can be created empty" do
    sparserange = SparseRange(Int64).new
    sparserange.should be_a SparseRange(Int64)
    sparserange.ranges.size.should eq 0
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange(Int64).new list: [1_i64..10_i64, 21_i64..30_i64]
    sparserange.should be_a SparseRange(Int64)
    sparserange.ranges.size.should eq 2
  end
  sparserange = SparseRange(Int64).new list: [-19_i64..-10_i64, 10_i64..19_i64, 30_i64..39_i64]
  it "calculates the min/max correctly" do
    sparserange.should be_a SparseRange(Int64)
    sparserange.min.should eq -19
    sparserange.max.should eq 39
  end
  it "adds integers" do
    sparserange.add 40_i64
    sparserange.ranges.should eq [-19_i64..-10_i64, 10_i64..19_i64, 30_i64..40_i64]
    sparserange.add 20_i64
    sparserange.ranges.should eq [-19_i64..-10_i64, 10_i64..20_i64, 30_i64..40_i64]
    sparserange.add -20_i64
    sparserange.ranges.should eq [-20_i64..-10_i64, 10_i64..20_i64, 30_i64..40_i64]
    sparserange.add 45_i64
    sparserange.ranges.should eq [-20_i64..-10_i64, 10_i64..20_i64, 30_i64..40_i64, 45_i64..45_i64]
    sparserange.add 25_i64
    sparserange.ranges.should eq [-20_i64..-10_i64, 10_i64..20_i64, 25_i64..25_i64, 30_i64..40_i64, 45_i64..45_i64]
    sparserange.add 15_i64
    sparserange.ranges.should eq [-20_i64..-10_i64, 10_i64..20_i64, 25_i64..25_i64, 30_i64..40_i64, 45_i64..45_i64]
    sparserange.add -5_i64
    sparserange.ranges.should eq [-20_i64..-10_i64, -5_i64..-5_i64, 10_i64..20_i64, 25_i64..25_i64, 30_i64..40_i64, 45_i64..45_i64]
    sparserange.add -25_i64
    sparserange.ranges.should eq [-25_i64..-25_i64, -20_i64..-10_i64, -5_i64..-5_i64, 10_i64..20_i64, 25_i64..25_i64, 30_i64..40_i64, 45_i64..45_i64]
  end
  it "adds ranges" do
    sparserange.add 27_i64..28_i64
    sparserange.ranges.should eq [-25_i64..-25_i64, -20_i64..-10_i64, -5_i64..-5_i64, 10_i64..20_i64, 25_i64..25_i64, 27_i64..28_i64, 30_i64..40_i64, 45_i64..45_i64]
    sparserange.add 50_i64..59_i64
    sparserange.ranges.should eq [-25_i64..-25_i64, -20_i64..-10_i64, -5_i64..-5_i64, 10_i64..20_i64, 25_i64..25_i64, 27_i64..28_i64, 30_i64..40_i64, 45_i64..45_i64, 50_i64..59_i64]
    sparserange.add 45_i64..50_i64
    sparserange.ranges.should eq [-25_i64..-25_i64, -20_i64..-10_i64, -5_i64..-5_i64, 10_i64..20_i64, 25_i64..25_i64, 27_i64..28_i64, 30_i64..40_i64, 45_i64..59_i64]
    sparserange.add -5_i64..10_i64
    sparserange.ranges.should eq [-25_i64..-25_i64, -20_i64..-10_i64, -5_i64..20_i64, 25_i64..25_i64, 27_i64..28_i64, 30_i64..40_i64, 45_i64..59_i64]
    sparserange.add -39_i64..-35_i64
    sparserange.ranges.should eq [-39_i64..-35_i64, -25_i64..-25_i64, -20_i64..-10_i64, -5_i64..20_i64, 25_i64..25_i64, 27_i64..28_i64, 30_i64..40_i64, 45_i64..59_i64]
    sparserange.add -33_i64..-27_i64
    sparserange.ranges.should eq [-39_i64..-35_i64, -33_i64..-27_i64, -25_i64..-25_i64, -20_i64..-10_i64, -5_i64..20_i64, 25_i64..25_i64, 27_i64..28_i64, 30_i64..40_i64, 45_i64..59_i64]
  end
  it "sorts the ranges" do
    sparserange = SparseRange(Int64).new list: [1_i64..10_i64, -19_i64..-9_i64, 21_i64..30_i64], assert: false
    sparserange.ranges.should eq [-19_i64..-9_i64, 1_i64..10_i64, 21_i64..30_i64]
  end
end

describe SparseRange(Float64) do
  it "can be created empty" do
    sparserange = SparseRange(Float64).new
    sparserange.should be_a SparseRange(Float64)
    sparserange.ranges.size.should eq 0_f64
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange(Float64).new list: [1_f64..10_f64, 21_f64..30_f64]
    sparserange.should be_a SparseRange(Float64)
    sparserange.ranges.size.should eq 2_f64
  end
  sparserange = SparseRange(Float64).new list: [-19_f64..-10_f64, 10_f64..19_f64, 30_f64..39_f64]
  it "calculates the min/max correctly" do
    sparserange.should be_a SparseRange(Float64)
    sparserange.min.should eq -19_f64
    sparserange.max.should eq 39_f64
  end
  it "adds floats" do
    sparserange.add 39_f64.next_float
    sparserange.ranges.should eq [-19_f64..-10_f64, 10_f64..19_f64, 30_f64..39_f64.next_float]
    sparserange.add 19_f64.next_float
    sparserange.ranges.should eq [-19_f64..-10_f64, 10_f64..19_f64.next_float, 30_f64..39_f64.next_float]
    sparserange.add -19_f64.prev_float
    sparserange.ranges.should eq [-19_f64.prev_float..-10_f64, 10_f64..19_f64.next_float, 30_f64..39_f64.next_float]
    sparserange.add 45_f64
    sparserange.ranges.should eq [-19_f64.prev_float..-10_f64, 10_f64..19_f64.next_float, 30_f64..39_f64.next_float, 45_f64..45_f64]
    sparserange.add 25_f64
    sparserange.ranges.should eq [-19_f64.prev_float..-10_f64, 10_f64..19_f64.next_float, 25_f64..25_f64, 30_f64..39_f64.next_float, 45_f64..45_f64]
    sparserange.add 15_f64
    sparserange.ranges.should eq [-19_f64.prev_float..-10_f64, 10_f64..19_f64.next_float, 25_f64..25_f64, 30_f64..39_f64.next_float, 45_f64..45_f64]
    sparserange.add -5_f64
    sparserange.ranges.should eq [-19_f64.prev_float..-10_f64, -5_f64..-5_f64, 10_f64..19_f64.next_float, 25_f64..25_f64, 30_f64..39_f64.next_float, 45_f64..45_f64]
    sparserange.add -25_f64
    sparserange.ranges.should eq [-25_f64..-25_f64, -19_f64.prev_float..-10_f64, -5_f64..-5_f64, 10_f64..19_f64.next_float, 25_f64..25_f64, 30_f64..39_f64.next_float, 45_f64..45_f64]
  end
  it "adds ranges" do
    sparserange.add 27_f64..28_f64
    sparserange.ranges.should eq [-25_f64..-25_f64, -19_f64.prev_float..-10_f64, -5_f64..-5_f64, 10_f64..19_f64.next_float, 25_f64..25_f64, 27_f64..28_f64, 30_f64..39_f64.next_float, 45_f64..45_f64]
    sparserange.add 50_f64..59_f64
    sparserange.ranges.should eq [-25_f64..-25_f64, -19_f64.prev_float..-10_f64, -5_f64..-5_f64, 10_f64..19_f64.next_float, 25_f64..25_f64, 27_f64..28_f64, 30_f64..39_f64.next_float, 45_f64..45_f64, 50_f64..59_f64]
    sparserange.add 45_f64..50_f64
    sparserange.ranges.should eq [-25_f64..-25_f64, -19_f64.prev_float..-10_f64, -5_f64..-5_f64, 10_f64..19_f64.next_float, 25_f64..25_f64, 27_f64..28_f64, 30_f64..39_f64.next_float, 45_f64..59_f64]
    sparserange.add -5_f64..10_f64.prev_float
    sparserange.ranges.should eq [-25_f64..-25_f64, -19_f64.prev_float..-10_f64, -5_f64..19_f64.next_float, 25_f64..25_f64, 27_f64..28_f64, 30_f64..39_f64.next_float, 45_f64..59_f64]
    sparserange.add -39_f64..-35_f64
    sparserange.ranges.should eq [-39_f64..-35_f64, -25_f64..-25_f64, -19_f64.prev_float..-10_f64, -5_f64..19_f64.next_float, 25_f64..25_f64, 27_f64..28_f64, 30_f64..39_f64.next_float, 45_f64..59_f64]
    sparserange.add -33_f64..-27_f64
    sparserange.ranges.should eq [-39_f64..-35_f64, -33_f64..-27_f64, -25_f64..-25_f64, -19_f64.prev_float..-10_f64, -5_f64..19_f64.next_float, 25_f64..25_f64, 27_f64..28_f64, 30_f64..39_f64.next_float, 45_f64..59_f64]
  end
  it "sorts the ranges" do
    sparserange = SparseRange(Float64).new list: [1_f64..10_f64, -19_f64..-9_f64, 21_f64..30_f64], assert: false
    sparserange.ranges.should eq [-19_f64..-9_f64, 1_f64..10_f64, 21_f64..30_f64]
  end
end
