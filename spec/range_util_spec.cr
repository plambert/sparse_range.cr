require "./spec_helper"

Spectator.describe Range do
  describe "#no_values?" do
    it "is false for a normal range" do
      expect((1..5).no_values?).to be_false
      expect((5..5).no_values?).to be_false
      expect((1...5).no_values?).to be_false
    end

    it "is true for a reversed or degenerate range" do
      expect((10..5).no_values?).to be_true
      expect((5...5).no_values?).to be_true
      expect((5...4).no_values?).to be_true
    end

    it "is false for an unbounded range" do
      expect((1..nil).no_values?).to be_false
      expect(Range(Int32?, Int32).new(nil, 5).no_values?).to be_false
    end
  end

  describe "#overlaps?" do
    it "detects shared values" do
      expect((1..5).overlaps?(4..8)).to be_true
      expect((4..8).overlaps?(1..5)).to be_true
      expect((1..10).overlaps?(3..4)).to be_true
      expect((3..4).overlaps?(1..10)).to be_true
      expect((5..5).overlaps?(5..5)).to be_true
    end

    it "is false for disjoint ranges" do
      expect((1..5).overlaps?(6..8)).to be_false
      expect((6..8).overlaps?(1..5)).to be_false
    end

    it "is false when either range holds no values" do
      expect((10..5).overlaps?(1..20)).to be_false
      expect((1..20).overlaps?(10..5)).to be_false
      expect((10..5).overlaps?(10..5)).to be_false
    end

    it "treats an open bound as infinite" do
      expect((1..nil).overlaps?(3..nil)).to be_true
      expect((1..nil).overlaps?(0..0)).to be_false
      expect((1..nil).overlaps?(0..5)).to be_true
      expect(Range(Int32?, Int32).new(nil, 5).overlaps?(3..9)).to be_true
      expect(Range(Int32?, Int32).new(nil, 3).overlaps?(5..9)).to be_false
    end

    it "raises for exclusive ranges" do
      expect { (1...5).overlaps?(2..3) }.to raise_error(ArgumentError)
      expect { (1..5).overlaps?(2...3) }.to raise_error(ArgumentError)
    end
  end

  describe "#abuts?" do
    it "detects adjacency in both directions" do
      expect((1..5).abuts?(6..8)).to be_true
      expect((6..8).abuts?(1..5)).to be_true
    end

    it "is false for a gap or an overlap" do
      expect((1..5).abuts?(7..8)).to be_false
      expect((1..5).abuts?(5..8)).to be_false
    end

    it "does not overflow at T::MAX" do
      expect((100_u8..199_u8).abuts?(200_u8..255_u8)).to be_true
      expect((200_u8..255_u8).abuts?(100_u8..199_u8)).to be_true
      expect((200_u8..255_u8).abuts?(0_u8..10_u8)).to be_false
      expect((0_i8..126_i8).abuts?(127_i8..127_i8)).to be_true
    end

    it "does not underflow at T::MIN" do
      expect((0_u8..5_u8).abuts?(6_u8..9_u8)).to be_true
      expect((6_u8..9_u8).abuts?(0_u8..5_u8)).to be_true
      expect((0_u8..5_u8).abuts?(100_u8..200_u8)).to be_false
    end

    it "raises for exclusive ranges" do
      expect { (1...5).abuts?(5..8) }.to raise_error(ArgumentError)
    end
  end

  describe "#merge?" do
    it "unions overlapping and abutting ranges" do
      expect((1..5).merge?(4..8)).to eq 1..8
      expect((4..8).merge?(1..5)).to eq 1..8
      expect((1..5).merge?(6..9)).to eq 1..9
      expect((1..10).merge?(3..4)).to eq 1..10
      expect((3..4).merge?(1..10)).to eq 1..10
    end

    it "returns nil for disjoint ranges" do
      expect((1..5).merge?(10..12)).to be_nil
    end
  end

  describe "#merge and #merge!" do
    it "falls back to the receiver, or raises" do
      expect((1..5).merge(10..12)).to eq 1..5
      expect((1..5).merge(4..8)).to eq 1..8
      expect((1..5).merge!(4..8)).to eq 1..8
      expect { (1..5).merge!(10..12) }.to raise_error(ArgumentError)
    end
  end

  describe "#<=>" do
    it "orders by begin, then end, then exclusivity" do
      expect(((1..5) <=> (2..5))).to eq -1
      expect(((2..5) <=> (1..5))).to eq 1
      expect(((1..5) <=> (1..9))).to eq -1
      expect(((1..5) <=> (1..5))).to eq 0
      expect(((1...5) <=> (1..5))).to eq -1
      expect(((1..5) <=> (1...5))).to eq 1
    end

    it "sorts an open begin first and an open end last" do
      expect((Range(Int32?, Int32).new(nil, 5) <=> Range(Int32?, Int32).new(1, 5))).to eq -1
      expect((Range(Int32, Int32?).new(1, nil) <=> Range(Int32, Int32?).new(1, 5))).to eq 1
      expect((Range(Int32, Int32?).new(1, 5) <=> Range(Int32, Int32?).new(1, nil))).to eq -1
    end

    it "sorts a list of ranges when used explicitly" do
      expect([5..6, 1..2, 3..4].sort { |a, b| a <=> b }).to eq [1..2, 3..4, 5..6]
    end
  end

  describe "the stdlib contract" do
    it "leaves Range non-Comparable, so the operators stay undefined" do
      # Making Range Comparable would silently enable `<`, `>` and `#clamp`
      # across every program that requires this shard, with semantics that
      # disagree with Range#== over exclusivity.
      expect((1..3).responds_to?(:clamp)).to be_false
      expect((1..3).responds_to?(:between?)).to be_false
    end

    it "leaves == honouring exclusivity" do
      expect(((1..3) == (1...3))).to be_false
      expect(((1..3) == (1..3))).to be_true
    end

    it "leaves === and hashing alone" do
      expect(((1..3) === 2)).to be_true
      expect(((1..3) === 9)).to be_false
      expect(({(1..3) => "a", (1...3) => "b"}.size)).to eq 2
    end
  end
end
