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
    sparserange.should be_a SparseRange(Int32)
    sparserange.min.should eq -19
    sparserange.max.should eq 39
  end

  it "adds integers" do
    sparserange.should be_a SparseRange(Int32)
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
    sparserange.should be_a SparseRange(Int32)
    sparserange.add(27..28)
    sparserange.ranges.should eq [-25..-25, -20..-10, -5..-5, 10..20, 25..25, 27..28, 30..40, 45..45]
    sparserange.add(50..59)
    sparserange.ranges.should eq [-25..-25, -20..-10, -5..-5, 10..20, 25..25, 27..28, 30..40, 45..45, 50..59]
    sparserange.add(45..50)
    sparserange.ranges.should eq [-25..-25, -20..-10, -5..-5, 10..20, 25..25, 27..28, 30..40, 45..59]
    sparserange.add(-5..10)
    sparserange.ranges.should eq [-25..-25, -20..-10, -5..20, 25..25, 27..28, 30..40, 45..59]
    sparserange.add(-39..-35)
    sparserange.ranges.should eq [-39..-35, -25..-25, -20..-10, -5..20, 25..25, 27..28, 30..40, 45..59]
    sparserange.add(-33..-27)
    sparserange.ranges.should eq [-39..-35, -33..-27, -25..-25, -20..-10, -5..20, 25..25, 27..28, 30..40, 45..59]
  end

  it "subtracts ranges" do
    sparserange.should be_a SparseRange(Int32)
    sparserange.add([27..28, 50..59, 45..50, -5..10, -39..-35, -33..-27])
    sparserange.ranges.should eq [-39..-35, -33..-27, -25..-25, -20..-10, -5..20, 25..25, 27..28, 30..40, 45..59]

    sparserange.subtract(27..28)
    sparserange.ranges.should eq [-39..-35, -33..-27, -25..-25, -20..-10, -5..20, 25..25, 30..40, 45..59]

    sparserange.subtract(25..31)
    sparserange.ranges.should eq [-39..-35, -33..-27, -25..-25, -20..-10, -5..20, 32..40, 45..59]

    sparserange.subtract(-36..-32)
    sparserange.ranges.should eq [-39..-37, -31..-27, -25..-25, -20..-10, -5..20, 32..40, 45..59]

    sparserange.subtract(-30..-28)
    sparserange.ranges.should eq [-39..-37, -31..-31, -27..-27, -25..-25, -20..-10, -5..20, 32..40, 45..59]

    sparserange.subtract(-30..-28)
    sparserange.ranges.should eq [-39..-37, -31..-31, -27..-27, -25..-25, -20..-10, -5..20, 32..40, 45..59]

    sparserange.subtract(47..55)
    sparserange.ranges.should eq [-39..-37, -31..-31, -27..-27, -25..-25, -20..-10, -5..20, 32..40, 45..46, 56..59]

    sparserange.subtract(47)
    sparserange.ranges.should eq [-39..-37, -31..-31, -27..-27, -25..-25, -20..-10, -5..20, 32..40, 45..46, 56..59]

    sparserange.subtract(-38)
    sparserange.ranges.should eq [-39..-39, -37..-37, -31..-31, -27..-27, -25..-25, -20..-10, -5..20, 32..40, 45..46, 56..59]
  end

  it "sorts the ranges" do
    sparserange = SparseRange(Int32).new list: [1..10, -19..-9, 21..30], assert: false
    sparserange.ranges.should eq [-19..-9, 1..10, 21..30]
  end

  it "can be created from a string" do
    sparserange = SparseRange(Int32).new(list: "1,3,5")
    sparserange.ranges.should eq [1_i32..1_i32, 3_i32..3_i32, 5_i32..5_i32]
    sparserange = SparseRange(Int32).new(list: "1..3")
    sparserange.ranges.should eq [1_i32..3_i32]
    sparserange = SparseRange(Int32).new(list: "1..3,5")
    sparserange.ranges.should eq [1_i32..3_i32, 5_i32..5_i32]
  end

  it "can invert the ranges" do
    sparserange = SparseRange(Int32).new(list: "1,3,5")
    result = [] of Int32
    sparserange.each_excluded(start_at: 0, end_at: 9) do |num|
      result << num
    end
    result.should eq [0, 2, 4, 6, 7, 8, 9]
  end

  it "correctly decides if it is crowded" do
    SparseRange(Int32).new(list: "1,2,3").crowded?.should be_true
    SparseRange(Int32).new(list: "1,2,30").crowded?.should be_false
    SparseRange(Int32).new(list: "1,2,3").crowded?(0..9).should be_false
    SparseRange(Int32).new(list: "1,2,3").crowded?(9).should be_false
    SparseRange(Int32).new(list: "1,2,3").crowded?(7).should be_false
  end
end
