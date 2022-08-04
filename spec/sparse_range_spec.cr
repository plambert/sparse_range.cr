require "./spec_helper"

describe SparseRange do
  it "can be created empty" do
    sparserange = SparseRange::Int32.new
    sparserange.should be_a SparseRange::Int32
    sparserange.ranges.size.should eq 0
  end
  it "can be created with a list of ranges" do
    sparserange = SparseRange::Int32.new list: [1..10, 21..30]
    sparserange.should be_a SparseRange::Int32
    sparserange.ranges.size.should eq 2
  end
  sparserange = SparseRange::Int32.new list: [-19..-10, 10..19, 30..39]
  it "calculates the min/max correctly" do
    # sparserange = SparseRange::Int32.new list: [1..10, 21..30]
    sparserange.should be_a SparseRange::Int32
    sparserange.min.should eq -19
    sparserange.max.should eq 39
  end
  it "adds integers" do
    # sparserange = SparseRange::Int32.new list: [1..10, 21..30]
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
    sparserange = SparseRange::Int32.new list: [1..10, -19..-9, 21..30], assert: false
    sparserange.ranges.should eq [-19..-9, 1..10, 21..30]
  end
end
