require "./spec_helper"

# Regression specs for the defects found in the 2026-08-07 audit.
#
# Each example here failed against the implementation as it stood before that
# audit; keep them passing.

describe SparseRange do
  describe "the class invariant" do
    it "holds under random add/subtract sequences" do
      random = Random.new 20260807
      200.times do
        sparserange = SparseRange(Int32).new
        model = Set(Int32).new
        20.times do
          low = random.rand -50..50
          high = low + random.rand 0..10
          if random.rand(2).zero?
            sparserange.add low..high
            (low..high).each { |value| model << value }
          else
            sparserange.subtract low..high
            (low..high).each { |value| model.delete value }
          end
          sparserange.assert?.should be_true
          seen = Set(Int32).new
          sparserange.each { |value| seen << value }
          seen.should eq model
          sparserange.count.should eq model.size
        end
      end
    end

    it "is rejected by assert? when a reversed range is present" do
      broken = SparseRange(Int32).new ranges: [1..0], assert: false, sort: false
      broken.assert?.should be_false
      expect_raises(SparseRange::AssertionError) { broken.assert! }
    end

    it "is rejected by assert? when an exclusive range is present" do
      broken = SparseRange(Int32).new ranges: [1...5], assert: false, sort: false
      broken.assert?.should be_false
    end
  end

  describe "#subtract" do
    it "trims rather than splitting when the subtrahend shares the lower bound" do
      sparserange = SparseRange(Int32).new list: "18..25"
      sparserange.subtract 18..20
      sparserange.ranges.should eq [21..25]
      sparserange.size.should eq 1
      sparserange.min.should eq 21
    end

    it "trims rather than splitting when the subtrahend shares the upper bound" do
      sparserange = SparseRange(Int32).new list: "18..25"
      sparserange.subtract 23..25
      sparserange.ranges.should eq [18..22]
      sparserange.size.should eq 1
      sparserange.max.should eq 22
    end

    it "removes a range covered exactly" do
      sparserange = SparseRange(Int32).new list: "1..10,20..30"
      sparserange.subtract 1..10
      sparserange.ranges.should eq [20..30]
    end

    it "never stores a reversed or empty range" do
      sparserange = SparseRange(Int32).new list: "1..10,20..30"
      [1..1, 10..10, 20..25, 26..30, 1..10, 5..5].each do |subtrahend|
        copy = sparserange.dup
        copy.subtract subtrahend
        copy.ranges.each do |range|
          range.begin.should be <= range.end
        end
      end
    end

    it "does not underflow at T::MIN for unsigned types" do
      sparserange = SparseRange(UInt8).new [0_u8..5_u8]
      sparserange.subtract 0_u8..2_u8
      sparserange.ranges.should eq [3_u8..5_u8]
    end

    it "does not overflow at T::MAX" do
      sparserange = SparseRange(UInt8).new [250_u8..255_u8]
      sparserange.subtract 253_u8..255_u8
      sparserange.ranges.should eq [250_u8..252_u8]
    end
  end

  describe "#add" do
    it "merges forward when the added range starts at T::MIN" do
      SparseRange(UInt8).new([6_u8..6_u8]).add(0_u8..144_u8).ranges.should eq [0_u8..144_u8]
      SparseRange(Int32).new([1..2, 100..200]).add(Int32::MIN..1000).ranges
        .should eq [Int32::MIN..1000]
    end

    it "coalesces a value that abuts the first range at T::MIN" do
      sparserange = SparseRange(UInt8).new [1_u8..235_u8]
      sparserange.add 0_u8
      sparserange.ranges.should eq [0_u8..235_u8]
      sparserange.assert?.should be_true
    end

    it "does not overflow when the added range ends at T::MAX" do
      sparserange = SparseRange(Int32).new [10..20]
      sparserange.add 21..Int32::MAX
      sparserange.ranges.should eq [10..Int32::MAX]
    end

    it "normalises exclusive ranges and drops empty ones" do
      SparseRange(Int32).new.add(5...10).ranges.should eq [5..9]
      SparseRange(Int32).new.add(5...5).ranges.should be_empty
      SparseRange(Int32).new([5...10]).ranges.should eq [5..9]
    end

    it "rejects reversed ranges" do
      expect_raises(ArgumentError) { SparseRange(Int32).new.add 10..5 }
      expect_raises(ArgumentError) { SparseRange(Int32).new [10..5] }
    end

    # These cases were worked out by hand while `add_one` was being written and
    # lived as a table at the bottom of README.md. They belong here, where they
    # are checked.
    it "matches the hand-worked merge table" do
      base = [10..12, 20..22, 30..32]
      {
        (0..2)   => [0..2, 10..12, 20..22, 30..32],
        (0..11)  => [0..12, 20..22, 30..32],
        (0..19)  => [0..22, 30..32],
        (10..15) => [10..15, 20..22, 30..32],
        (15..17) => [10..12, 15..17, 20..22, 30..32],
        (15..19) => [10..12, 15..22, 30..32],
        (21..25) => [10..12, 20..25, 30..32],
        (11..31) => [10..32],
        (25..29) => [10..12, 20..22, 25..32],
        (25..31) => [10..12, 20..22, 25..32],
        (30..35) => [10..12, 20..22, 30..35],
        (33..33) => [10..12, 20..22, 30..33],
        (35..39) => [10..12, 20..22, 30..32, 35..39],
      }.each do |added, expected|
        sparserange = SparseRange(Int32).new base
        sparserange.add added
        sparserange.ranges.should eq expected
        sparserange.assert?.should be_true
      end
    end

    it "is order independent" do
      forward = SparseRange(Int32).new.add(1..3, 5..7, 9..11)
      reverse = SparseRange(Int32).new.add(9..11, 5..7, 1..3)
      forward.ranges.should eq reverse.ranges
    end
  end

  describe "#sort!" do
    it "keeps the widest end when one range contains another" do
      SparseRange(Int32).new([1..100, 5..10], assert: false).ranges.should eq [1..100]
      SparseRange(Int32).new([1..100, 5..10, 200..300], assert: false).ranges
        .should eq [1..100, 200..300]
    end

    it "does not underflow at T::MIN" do
      SparseRange(Int32).new([Int32::MIN..1, Int32::MIN..3], assert: false).ranges
        .should eq [Int32::MIN..3]
    end
  end

  describe "the ranges: initializer" do
    it "validates by default" do
      expect_raises(SparseRange::AssertionError) do
        SparseRange(Int32).new ranges: [30..39, 1..3, 2..5]
      end
    end

    it "sorts when asked not to assert" do
      SparseRange(Int32).new(ranges: [10..12, 1..3], assert: false).ranges
        .should eq [1..3, 10..12]
    end

    it "copies the array it is given" do
      source = [1..3, 10..12]
      sparserange = SparseRange(Int32).new ranges: source
      source << (100..200)
      sparserange.ranges.should eq [1..3, 10..12]
    end
  end

  describe "the list: initializer" do
    it "sorts, coalesces and normalises" do
      SparseRange(Int32).new(list: "5,1").ranges.should eq [1..1, 5..5]
      SparseRange(Int32).new(list: "1,1,1").ranges.should eq [1..1]
      SparseRange(Int32).new(list: "1..3,2..5").ranges.should eq [1..5]
      SparseRange(Int32).new(list: "1...5").ranges.should eq [1..4]
      SparseRange(Int32).new(list: "5,1,3").assert?.should be_true
    end

    it "raises on unparseable input instead of returning an empty set" do
      ["garbage", "1,,2", "1-5", "[1,2", "1..", "1..2..3"].each do |bad|
        expect_raises(SparseRange::ParseException) { SparseRange(Int32).new list: bad }
      end
    end

    it "accepts an empty string" do
      SparseRange(Int32).new(list: "").ranges.should be_empty
      SparseRange(Int32).new(list: "  ").ranges.should be_empty
      SparseRange(Int32).new(list: "[]").ranges.should be_empty
    end

    it "raises ParseException rather than ArgumentError when a value does not fit T" do
      expect_raises(SparseRange::ParseException) do
        SparseRange(Int32).new list: "9999999999999999999999"
      end
    end
  end

  describe "#each_excluded" do
    it "clamps the yielded gaps to end_at" do
      sparserange = SparseRange(Int32).new list: "10..12,20..22"
      result = [] of Int32
      sparserange.each_excluded(0, 15) { |value| result << value }
      result.should eq [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 13, 14, 15]
    end

    it "starts at start_at rather than at min" do
      sparserange = SparseRange(Int32).new list: "10..12,20..22"
      result = [] of Int32
      sparserange.each_excluded(15, 15) { |value| result << value }
      result.should eq [15]
    end

    it "handles a window entirely above max" do
      sparserange = SparseRange(Int32).new list: "10..12,20..22"
      result = [] of Int32
      sparserange.each_excluded(30, 33) { |value| result << value }
      result.should eq [30, 31, 32, 33]
    end

    it "yields nothing for a window inside a range" do
      sparserange = SparseRange(Int32).new list: "10..12,20..22"
      result = [] of Int32
      sparserange.each_excluded(11, 11) { |value| result << value }
      result.should be_empty
    end

    it "yields the whole window for an empty SparseRange" do
      result = [] of Int32
      SparseRange(Int32).new.each_excluded(0, 5) { |value| result << value }
      result.should eq [0, 1, 2, 3, 4, 5]
    end

    it "does not overflow at T::MAX" do
      result = 0
      SparseRange(Int8).new([0_i8..Int8::MAX]).each_excluded { |_| result += 1 }
      result.should eq 0
    end
  end

  describe "#to_bitarray" do
    it "covers 0..max inclusive" do
      SparseRange(Int32).new(list: "1,3,5").to_bitstring.should eq "010101"
      SparseRange(Int32).new(list: "0..3").to_bitstring.should eq "1111"
      SparseRange(Int32).new(list: "5").to_bitstring.should eq "000001"
      SparseRange(Int32).new(list: "0").to_bitstring.should eq "1"
      SparseRange(Int32).new.to_bitstring.should eq ""
    end

    it "does not raise for a sparse set" do
      bits = SparseRange(Int32).new(list: "1,3,50").to_bitarray
      bits.size.should eq 51
      bits[1].should be_true
      bits[3].should be_true
      bits[50].should be_true
      bits[0].should be_false
      bits[2].should be_false
    end

    it "works for a crowded set" do
      SparseRange(Int32).new(list: "0..8,10").to_bitstring.should eq "11111111101"
    end
  end

  describe "#count" do
    it "is invalidated by clear" do
      sparserange = SparseRange(Int32).new list: "1..10"
      sparserange.count.should eq 10
      sparserange.clear
      sparserange.empty?.should be_true
      sparserange.count.should eq 0
    end

    it "is invalidated by sort!" do
      sparserange = SparseRange(Int32).new ranges: [1..2, 4..5], assert: false
      sparserange.count.should eq 4
      sparserange.add 3
      sparserange.count.should eq 5
    end

    it "does not wrap for wide ranges" do
      SparseRange(Int32).new([0..Int32::MAX]).count.should eq 2147483648_u128
      SparseRange(Int32).new([Int32::MIN..Int32::MAX]).count.should eq 4294967296_u128
    end

    it "compiles and works for every supported type" do
      SparseRange(Int8).new([1_i8..3_i8]).count.should eq 3
      SparseRange(UInt8).new([1_u8..3_u8]).count.should eq 3
      SparseRange(Int16).new([1_i16..3_i16]).count.should eq 3
      SparseRange(UInt16).new([1_u16..3_u16]).count.should eq 3
      SparseRange(Int64).new([1_i64..3_i64]).count.should eq 3
      SparseRange(UInt64).new([1_u64..3_u64]).count.should eq 3
      SparseRange(Int128).new([1_i128..3_i128]).count.should eq 3
      SparseRange(UInt128).new([1_u128..3_u128]).count.should eq 3
    end
  end

  describe "#span" do
    it "does not overflow across the full width of T" do
      SparseRange(UInt8).new([0_u8..255_u8]).span.should eq 256
      SparseRange(Int8).new([Int8::MIN..Int8::MAX]).span.should eq 256
      SparseRange(Int32).new([Int32::MIN..Int32::MAX]).span.should eq 4294967296_u128
    end
  end

  describe "#invert" do
    it "inverts a set touching T::MIN" do
      SparseRange(Int8).new([Int8::MIN..0_i8]).invert.ranges.should eq [1_i8..Int8::MAX]
    end

    it "inverts a set touching T::MAX" do
      SparseRange(Int8).new([0_i8..Int8::MAX]).invert.ranges.should eq [Int8::MIN..(-1_i8)]
    end

    it "inverts the full domain to the empty set" do
      SparseRange(Int8).new([Int8::MIN..Int8::MAX]).invert.empty?.should be_true
    end

    it "inverts the empty set to the full domain" do
      SparseRange(Int8).new.invert.ranges.should eq [Int8::MIN..Int8::MAX]
    end

    it "round-trips" do
      sparserange = SparseRange(Int8).new list: "1..3,10..20"
      sparserange.invert.invert.ranges.should eq sparserange.ranges
    end
  end

  describe "#invert!" do
    it "inverts in place" do
      sparserange = SparseRange(Int8).new [0_i8..Int8::MAX]
      sparserange.invert!
      sparserange.ranges.should eq [Int8::MIN..(-1_i8)]
    end
  end

  describe "the integer width conversions" do
    it "converts when the values fit" do
      SparseRange(Int32).new(list: "1..3,10..12").to_i64?.try(&.ranges)
        .should eq [1_i64..3_i64, 10_i64..12_i64]
      SparseRange(Int32).new(list: "1..3").to_u16?.try(&.ranges).should eq [1_u16..3_u16]
      SparseRange(Int32).new(list: "1..3").to_u128?.try(&.ranges).should eq [1_u128..3_u128]
    end

    it "returns the same set for the identity conversion" do
      SparseRange(Int32).new(list: "1..3").to_i32?.try(&.ranges).should eq [1..3]
    end

    it "returns nil when a value does not fit" do
      SparseRange(Int32).new(list: "-5..-1").to_u32?.should be_nil
      SparseRange(Int32).new(list: "-5..-1").to_u16?.should be_nil
      SparseRange(Int64).new(list: "70000").to_u16?.should be_nil
    end

    it "converts the empty set" do
      SparseRange(Int32).new.to_u64?.try(&.empty?).should be_true
    end
  end

  describe "JSON" do
    it "round-trips" do
      sparserange = SparseRange(Int32).new list: "1..3,10..12"
      SparseRange(Int32).from_json(sparserange.to_json).ranges.should eq sparserange.ranges
    end

    it "does not leak internal state" do
      sparserange = SparseRange(Int32).new list: "1..3"
      before = sparserange.to_json
      sparserange.count
      sparserange.to_json.should eq before
      before.should eq "[[1,3]]"
    end

    it "round-trips the empty set" do
      SparseRange(Int32).from_json(SparseRange(Int32).new.to_json).empty?.should be_true
    end

    it "rejects malformed input" do
      expect_raises(JSON::ParseException) { SparseRange(Int32).from_json "[[3,1]]" }
    end
  end

  describe "non-mutating operators" do
    it "leaves the receiver alone" do
      original = SparseRange(Int32).new list: "1..10"
      (original + (20..30)).ranges.should eq [1..10, 20..30]
      (original - (5..6)).ranges.should eq [1..4, 7..10]
      original.ranges.should eq [1..10]
    end
  end

  describe "#dup" do
    it "produces an independent copy" do
      original = SparseRange(Int32).new list: "1..3,10..12"
      copy = original.dup
      copy.add 100
      original.ranges.should eq [1..3, 10..12]
      copy.ranges.should eq [1..3, 10..12, 100..100]
    end
  end

  describe "iterators" do
    it "exposes each and each_range without a block" do
      sparserange = SparseRange(Int32).new list: "1..3,10..11"
      sparserange.each.to_a.should eq [1, 2, 3, 10, 11]
      sparserange.each_range.to_a.should eq [1..3, 10..11]
    end
  end

  describe "the empty set" do
    it "raises IndexError for min, max and span" do
      empty = SparseRange(Int32).new
      expect_raises(IndexError) { empty.min }
      expect_raises(IndexError) { empty.max }
      expect_raises(IndexError) { empty.span }
      empty.min?.should be_nil
      empty.max?.should be_nil
      empty.span?.should be_nil
    end
  end

  describe "#crowded?" do
    it "accepts an explicit window" do
      sparserange = SparseRange(Int32).new list: "1,2,3"
      sparserange.crowded?(0, 5).should be_true
      sparserange.crowded?(0, 9).should be_false
    end
  end

  describe "the convenience constructors" do
    it "exist for every supported type, including 8-bit" do
      SparseRange.new(Int8).should be_a SparseRange(Int8)
      SparseRange.new(UInt8).should be_a SparseRange(UInt8)
      SparseRange.new(Int128).should be_a SparseRange(Int128)
      SparseRange.new(UInt128).should be_a SparseRange(UInt128)
    end

    it "forward named arguments" do
      SparseRange.new(Int32, list: "1..5,7").ranges.should eq [1..5, 7..7]
      SparseRange.new(Int32, ranges: [1..5, 10..12]).ranges.should eq [1..5, 10..12]
    end

    it "forward positional arguments" do
      SparseRange.new(Int32, [1..5]).ranges.should eq [1..5]
    end
  end
end
