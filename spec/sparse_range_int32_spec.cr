require "./spec_helper"

Spectator.describe SparseRange(Int32) do
  let(sparserange) { SparseRange(Int32).new list: [-19..-10, 10..19, 30..39] }

  it "can be created empty" do
    sparserange = SparseRange(Int32).new
    expect(sparserange).to be_a SparseRange(Int32)
    expect(sparserange.ranges.size).to eq 0
  end

  it "can be created with a list of ranges" do
    sparserange = SparseRange(Int32).new list: [1..10, 21..30]
    expect(sparserange).to be_a SparseRange(Int32)
    expect(sparserange.ranges.size).to eq 2
  end

  it "calculates the min/max correctly" do
    expect(sparserange.min).to eq -19
    expect(sparserange.max).to eq 39
  end

  it "adds integers" do
    sparserange.add 40
    expect(sparserange.ranges).to eq [-19..-10, 10..19, 30..40]
    sparserange.add 20
    expect(sparserange.ranges).to eq [-19..-10, 10..20, 30..40]
    sparserange.add -20
    expect(sparserange.ranges).to eq [-20..-10, 10..20, 30..40]
    sparserange.add 45
    expect(sparserange.ranges).to eq [-20..-10, 10..20, 30..40, 45..45]
    sparserange.add 25
    expect(sparserange.ranges).to eq [-20..-10, 10..20, 25..25, 30..40, 45..45]
    sparserange.add 15
    expect(sparserange.ranges).to eq [-20..-10, 10..20, 25..25, 30..40, 45..45]
    sparserange.add -5
    expect(sparserange.ranges).to eq [-20..-10, -5..-5, 10..20, 25..25, 30..40, 45..45]
    sparserange.add -25
    expect(sparserange.ranges).to eq [-25..-25, -20..-10, -5..-5, 10..20, 25..25, 30..40, 45..45]
  end

  it "adds ranges" do
    sparserange = SparseRange(Int32).new list: [-25..-25, -20..-10, -5..-5, 10..20, 25..25, 30..40, 45..45]
    sparserange.add(27..28)
    expect(sparserange.ranges).to eq [-25..-25, -20..-10, -5..-5, 10..20, 25..25, 27..28, 30..40, 45..45]
    sparserange.add(50..59)
    expect(sparserange.ranges).to eq [-25..-25, -20..-10, -5..-5, 10..20, 25..25, 27..28, 30..40, 45..45, 50..59]
    sparserange.add(45..50)
    expect(sparserange.ranges).to eq [-25..-25, -20..-10, -5..-5, 10..20, 25..25, 27..28, 30..40, 45..59]
    sparserange.add(-5..10)
    expect(sparserange.ranges).to eq [-25..-25, -20..-10, -5..20, 25..25, 27..28, 30..40, 45..59]
    sparserange.add(-39..-35)
    expect(sparserange.ranges).to eq [-39..-35, -25..-25, -20..-10, -5..20, 25..25, 27..28, 30..40, 45..59]
    sparserange.add(-33..-27)
    expect(sparserange.ranges).to eq [-39..-35, -33..-27, -25..-25, -20..-10, -5..20, 25..25, 27..28, 30..40, 45..59]
  end

  it "subtracts ranges" do
    sparserange = SparseRange(Int32).new list: [-25..-25, -20..-10, -5..-5, 10..20, 25..25, 30..40, 45..45]
    sparserange.add([27..28, 50..59, 45..50, -5..10, -39..-35, -33..-27])
    expect(sparserange.ranges).to eq [-39..-35, -33..-27, -25..-25, -20..-10, -5..20, 25..25, 27..28, 30..40, 45..59]

    sparserange.subtract(27..28)
    expect(sparserange.ranges).to eq [-39..-35, -33..-27, -25..-25, -20..-10, -5..20, 25..25, 30..40, 45..59]

    sparserange.subtract(25..31)
    expect(sparserange.ranges).to eq [-39..-35, -33..-27, -25..-25, -20..-10, -5..20, 32..40, 45..59]

    sparserange.subtract(-36..-32)
    expect(sparserange.ranges).to eq [-39..-37, -31..-27, -25..-25, -20..-10, -5..20, 32..40, 45..59]

    sparserange.subtract(-30..-28)
    expect(sparserange.ranges).to eq [-39..-37, -31..-31, -27..-27, -25..-25, -20..-10, -5..20, 32..40, 45..59]

    sparserange.subtract(-30..-28)
    expect(sparserange.ranges).to eq [-39..-37, -31..-31, -27..-27, -25..-25, -20..-10, -5..20, 32..40, 45..59]

    sparserange.subtract(47..55)
    expect(sparserange.ranges).to eq [-39..-37, -31..-31, -27..-27, -25..-25, -20..-10, -5..20, 32..40, 45..46, 56..59]

    sparserange.subtract(47)
    expect(sparserange.ranges).to eq [-39..-37, -31..-31, -27..-27, -25..-25, -20..-10, -5..20, 32..40, 45..46, 56..59]

    sparserange.subtract(-38)
    expect(sparserange.ranges).to eq [-39..-39, -37..-37, -31..-31, -27..-27, -25..-25, -20..-10, -5..20, 32..40, 45..46, 56..59]
  end

  it "sorts the ranges" do
    sparserange = SparseRange(Int32).new list: [1..10, -19..-9, 21..30], assert: false
    expect(sparserange.ranges).to eq [-19..-9, 1..10, 21..30]
  end

  it "can be created from a string" do
    sparserange = SparseRange(Int32).new(list: "1,3,5")
    expect(sparserange.ranges).to eq [1_i32..1_i32, 3_i32..3_i32, 5_i32..5_i32]
    sparserange = SparseRange(Int32).new(list: "1..3")
    expect(sparserange.ranges).to eq [1_i32..3_i32]
    sparserange = SparseRange(Int32).new(list: "1..3,5")
    expect(sparserange.ranges).to eq [1_i32..3_i32, 5_i32..5_i32]
  end

  it "iterates the excluded values" do
    sparserange = SparseRange(Int32).new(list: "1,3,5")
    result = [] of Int32
    sparserange.each_excluded(start_at: 0, end_at: 9) do |num|
      result << num
    end
    expect(result).to eq [0, 2, 4, 6, 7, 8, 9]
  end

  it "correctly decides if it is crowded" do
    expect(SparseRange(Int32).new(list: "1,2,3").crowded?).to be_true
    expect(SparseRange(Int32).new(list: "1,2,30").crowded?).to be_false
    expect(SparseRange(Int32).new(list: "1,2,3").crowded?(0..9)).to be_false
    expect(SparseRange(Int32).new(list: "1,2,3").crowded?(9)).to be_false
    expect(SparseRange(Int32).new(list: "1,2,3").crowded?(7)).to be_false
  end
end
