require "./spec_helper"

describe Range do
  describe "#no_values?" do
    it "is false for a normal range" do
      (1..5).no_values?.should be_false
      (5..5).no_values?.should be_false
      (1...5).no_values?.should be_false
    end

    it "is true for a reversed or degenerate range" do
      (10..5).no_values?.should be_true
      (5...5).no_values?.should be_true
      (5...4).no_values?.should be_true
    end

    it "is false for an unbounded range" do
      (1..nil).no_values?.should be_false
      Range(Int32?, Int32).new(nil, 5).no_values?.should be_false
    end
  end

  describe "#overlaps?" do
    it "detects shared values" do
      (1..5).overlaps?(4..8).should be_true
      (4..8).overlaps?(1..5).should be_true
      (1..10).overlaps?(3..4).should be_true
      (3..4).overlaps?(1..10).should be_true
      (5..5).overlaps?(5..5).should be_true
    end

    it "is false for disjoint ranges" do
      (1..5).overlaps?(6..8).should be_false
      (6..8).overlaps?(1..5).should be_false
    end

    it "is false when either range holds no values" do
      (10..5).overlaps?(1..20).should be_false
      (1..20).overlaps?(10..5).should be_false
      (10..5).overlaps?(10..5).should be_false
    end

    it "treats an open bound as infinite" do
      (1..nil).overlaps?(3..nil).should be_true
      (1..nil).overlaps?(0..0).should be_false
      (1..nil).overlaps?(0..5).should be_true
      Range(Int32?, Int32).new(nil, 5).overlaps?(3..9).should be_true
      Range(Int32?, Int32).new(nil, 3).overlaps?(5..9).should be_false
    end

    it "raises for exclusive ranges" do
      expect_raises(ArgumentError) { (1...5).overlaps?(2..3) }
      expect_raises(ArgumentError) { (1..5).overlaps?(2...3) }
    end
  end

  describe "#abuts?" do
    it "detects adjacency in both directions" do
      (1..5).abuts?(6..8).should be_true
      (6..8).abuts?(1..5).should be_true
    end

    it "is false for a gap or an overlap" do
      (1..5).abuts?(7..8).should be_false
      (1..5).abuts?(5..8).should be_false
    end

    it "does not overflow at T::MAX" do
      (100_u8..199_u8).abuts?(200_u8..255_u8).should be_true
      (200_u8..255_u8).abuts?(100_u8..199_u8).should be_true
      (200_u8..255_u8).abuts?(0_u8..10_u8).should be_false
      (0_i8..126_i8).abuts?(127_i8..127_i8).should be_true
    end

    it "does not underflow at T::MIN" do
      (0_u8..5_u8).abuts?(6_u8..9_u8).should be_true
      (6_u8..9_u8).abuts?(0_u8..5_u8).should be_true
      (0_u8..5_u8).abuts?(100_u8..200_u8).should be_false
    end

    it "raises for exclusive ranges" do
      expect_raises(ArgumentError) { (1...5).abuts?(5..8) }
    end
  end

  describe "#merge?" do
    it "unions overlapping and abutting ranges" do
      (1..5).merge?(4..8).should eq 1..8
      (4..8).merge?(1..5).should eq 1..8
      (1..5).merge?(6..9).should eq 1..9
      (1..10).merge?(3..4).should eq 1..10
      (3..4).merge?(1..10).should eq 1..10
    end

    it "returns nil for disjoint ranges" do
      (1..5).merge?(10..12).should be_nil
    end
  end

  describe "#merge and #merge!" do
    it "falls back to the receiver, or raises" do
      (1..5).merge(10..12).should eq 1..5
      (1..5).merge(4..8).should eq 1..8
      (1..5).merge!(4..8).should eq 1..8
      expect_raises(ArgumentError) { (1..5).merge!(10..12) }
    end
  end

  describe "#<=>" do
    it "orders by begin, then end, then exclusivity" do
      ((1..5) <=> (2..5)).should eq -1
      ((2..5) <=> (1..5)).should eq 1
      ((1..5) <=> (1..9)).should eq -1
      ((1..5) <=> (1..5)).should eq 0
      ((1...5) <=> (1..5)).should eq -1
      ((1..5) <=> (1...5)).should eq 1
    end

    it "sorts an open begin first and an open end last" do
      (Range(Int32?, Int32).new(nil, 5) <=> Range(Int32?, Int32).new(1, 5)).should eq -1
      (Range(Int32, Int32?).new(1, nil) <=> Range(Int32, Int32?).new(1, 5)).should eq 1
      (Range(Int32, Int32?).new(1, 5) <=> Range(Int32, Int32?).new(1, nil)).should eq -1
    end

    it "sorts a list of ranges when used explicitly" do
      [5..6, 1..2, 3..4].sort { |a, b| a <=> b }.should eq [1..2, 3..4, 5..6]
    end
  end

  describe "the stdlib contract" do
    it "leaves Range non-Comparable, so the operators stay undefined" do
      # Making Range Comparable would silently enable `<`, `>` and `#clamp`
      # across every program that requires this shard, with semantics that
      # disagree with Range#== over exclusivity.
      (1..3).responds_to?(:clamp).should be_false
      (1..3).responds_to?(:between?).should be_false
    end

    it "leaves == honouring exclusivity" do
      ((1..3) == (1...3)).should be_false
      ((1..3) == (1..3)).should be_true
    end

    it "leaves === and hashing alone" do
      ((1..3) === 2).should be_true
      ((1..3) === 9).should be_false
      ({(1..3) => "a", (1...3) => "b"}.size).should eq 2
    end
  end
end
