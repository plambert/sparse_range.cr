require "./spec_helper"

# Regression specs for the defects found in the 2026-08-07 audit.
#
# Each example here failed against the implementation as it stood before that
# audit; keep them passing.

Spectator.describe SparseRange do
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
          expect(sparserange.assert?).to be_true
          seen = Set(Int32).new
          sparserange.each { |value| seen << value }
          expect(seen).to eq model
          expect(sparserange.count).to eq model.size
        end
      end
    end

    it "is rejected by assert? when a reversed range is present" do
      broken = SparseRange(Int32).new ranges: [1..0], assert: false, sort: false
      expect(broken.assert?).to be_false
      expect { broken.assert! }.to raise_error(SparseRange::AssertionError)
    end

    it "is rejected by assert? when an exclusive range is present" do
      broken = SparseRange(Int32).new ranges: [1...5], assert: false, sort: false
      expect(broken.assert?).to be_false
    end
  end

  describe "#subtract" do
    it "trims rather than splitting when the subtrahend shares the lower bound" do
      sparserange = SparseRange(Int32).new list: "18..25"
      sparserange.subtract 18..20
      expect(sparserange.ranges).to eq [21..25]
      expect(sparserange.size).to eq 1
      expect(sparserange.min).to eq 21
    end

    it "trims rather than splitting when the subtrahend shares the upper bound" do
      sparserange = SparseRange(Int32).new list: "18..25"
      sparserange.subtract 23..25
      expect(sparserange.ranges).to eq [18..22]
      expect(sparserange.size).to eq 1
      expect(sparserange.max).to eq 22
    end

    it "removes a range covered exactly" do
      sparserange = SparseRange(Int32).new list: "1..10,20..30"
      sparserange.subtract 1..10
      expect(sparserange.ranges).to eq [20..30]
    end

    it "never stores a reversed or empty range" do
      sparserange = SparseRange(Int32).new list: "1..10,20..30"
      [1..1, 10..10, 20..25, 26..30, 1..10, 5..5].each do |subtrahend|
        copy = sparserange.dup
        copy.subtract subtrahend
        copy.ranges.each do |range|
          expect(range.begin).to be <= range.end
        end
      end
    end

    it "does not underflow at T::MIN for unsigned types" do
      sparserange = SparseRange(UInt8).new [0_u8..5_u8]
      sparserange.subtract 0_u8..2_u8
      expect(sparserange.ranges).to eq [3_u8..5_u8]
    end

    it "does not overflow at T::MAX" do
      sparserange = SparseRange(UInt8).new [250_u8..255_u8]
      sparserange.subtract 253_u8..255_u8
      expect(sparserange.ranges).to eq [250_u8..252_u8]
    end
  end

  describe "#add" do
    it "merges forward when the added range starts at T::MIN" do
      expect(SparseRange(UInt8).new([6_u8..6_u8]).add(0_u8..144_u8).ranges).to eq [0_u8..144_u8]
      expect(SparseRange(Int32).new([1..2, 100..200]).add(Int32::MIN..1000).ranges).to eq [Int32::MIN..1000]
    end

    it "coalesces a value that abuts the first range at T::MIN" do
      sparserange = SparseRange(UInt8).new [1_u8..235_u8]
      sparserange.add 0_u8
      expect(sparserange.ranges).to eq [0_u8..235_u8]
      expect(sparserange.assert?).to be_true
    end

    it "does not overflow when the added range ends at T::MAX" do
      sparserange = SparseRange(Int32).new [10..20]
      sparserange.add 21..Int32::MAX
      expect(sparserange.ranges).to eq [10..Int32::MAX]
    end

    it "normalises exclusive ranges and drops empty ones" do
      expect(SparseRange(Int32).new.add(5...10).ranges).to eq [5..9]
      expect(SparseRange(Int32).new.add(5...5).ranges).to be_empty
      expect(SparseRange(Int32).new([5...10]).ranges).to eq [5..9]
    end

    it "rejects reversed ranges" do
      expect { SparseRange(Int32).new.add 10..5 }.to raise_error(ArgumentError)
      expect { SparseRange(Int32).new [10..5] }.to raise_error(ArgumentError)
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
        expect(sparserange.ranges).to eq expected
        expect(sparserange.assert?).to be_true
      end
    end

    it "is order independent" do
      forward = SparseRange(Int32).new.add(1..3, 5..7, 9..11)
      reverse = SparseRange(Int32).new.add(9..11, 5..7, 1..3)
      expect(forward.ranges).to eq reverse.ranges
    end
  end

  describe "#sort!" do
    it "keeps the widest end when one range contains another" do
      expect(SparseRange(Int32).new([1..100, 5..10], assert: false).ranges).to eq [1..100]
      expect(SparseRange(Int32).new([1..100, 5..10, 200..300], assert: false).ranges).to eq [1..100, 200..300]
    end

    it "does not underflow at T::MIN" do
      expect(SparseRange(Int32).new([Int32::MIN..1, Int32::MIN..3], assert: false).ranges).to eq [Int32::MIN..3]
    end
  end

  describe "the ranges: initializer" do
    it "validates by default" do
      expect do
        SparseRange(Int32).new ranges: [30..39, 1..3, 2..5]
      end.to raise_error(SparseRange::AssertionError)
    end

    it "sorts when asked not to assert" do
      expect(SparseRange(Int32).new(ranges: [10..12, 1..3], assert: false).ranges).to eq [1..3, 10..12]
    end

    it "copies the array it is given" do
      source = [1..3, 10..12]
      sparserange = SparseRange(Int32).new ranges: source
      source << (100..200)
      expect(sparserange.ranges).to eq [1..3, 10..12]
    end
  end

  describe "the list: initializer" do
    it "sorts, coalesces and normalises" do
      expect(SparseRange(Int32).new(list: "5,1").ranges).to eq [1..1, 5..5]
      expect(SparseRange(Int32).new(list: "1,1,1").ranges).to eq [1..1]
      expect(SparseRange(Int32).new(list: "1..3,2..5").ranges).to eq [1..5]
      expect(SparseRange(Int32).new(list: "1...5").ranges).to eq [1..4]
      expect(SparseRange(Int32).new(list: "5,1,3").assert?).to be_true
    end

    it "raises on unparseable input instead of returning an empty set" do
      ["garbage", "1,,2", "1-5", "[1,2", "1..", "1..2..3"].each do |bad|
        expect { SparseRange(Int32).new list: bad }.to raise_error(SparseRange::ParseException)
      end
    end

    it "accepts an empty string" do
      expect(SparseRange(Int32).new(list: "").ranges).to be_empty
      expect(SparseRange(Int32).new(list: "  ").ranges).to be_empty
      expect(SparseRange(Int32).new(list: "[]").ranges).to be_empty
    end

    it "raises ParseException rather than ArgumentError when a value does not fit T" do
      expect do
        SparseRange(Int32).new list: "9999999999999999999999"
      end.to raise_error(SparseRange::ParseException)
    end
  end

  describe "#each_excluded" do
    it "clamps the yielded gaps to end_at" do
      sparserange = SparseRange(Int32).new list: "10..12,20..22"
      result = [] of Int32
      sparserange.each_excluded(0, 15) { |value| result << value }
      expect(result).to eq [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 13, 14, 15]
    end

    it "starts at start_at rather than at min" do
      sparserange = SparseRange(Int32).new list: "10..12,20..22"
      result = [] of Int32
      sparserange.each_excluded(15, 15) { |value| result << value }
      expect(result).to eq [15]
    end

    it "handles a window entirely above max" do
      sparserange = SparseRange(Int32).new list: "10..12,20..22"
      result = [] of Int32
      sparserange.each_excluded(30, 33) { |value| result << value }
      expect(result).to eq [30, 31, 32, 33]
    end

    it "yields nothing for a window inside a range" do
      sparserange = SparseRange(Int32).new list: "10..12,20..22"
      result = [] of Int32
      sparserange.each_excluded(11, 11) { |value| result << value }
      expect(result).to be_empty
    end

    it "yields the whole window for an empty SparseRange" do
      result = [] of Int32
      SparseRange(Int32).new.each_excluded(0, 5) { |value| result << value }
      expect(result).to eq [0, 1, 2, 3, 4, 5]
    end

    it "does not overflow at T::MAX" do
      result = 0
      SparseRange(Int8).new([0_i8..Int8::MAX]).each_excluded { |_| result += 1 }
      expect(result).to eq 0
    end
  end

  describe "#to_bitarray" do
    it "covers 0..max inclusive" do
      expect(SparseRange(Int32).new(list: "1,3,5").to_bitstring).to eq "010101"
      expect(SparseRange(Int32).new(list: "0..3").to_bitstring).to eq "1111"
      expect(SparseRange(Int32).new(list: "5").to_bitstring).to eq "000001"
      expect(SparseRange(Int32).new(list: "0").to_bitstring).to eq "1"
      expect(SparseRange(Int32).new.to_bitstring).to eq ""
    end

    it "does not raise for a sparse set" do
      bits = SparseRange(Int32).new(list: "1,3,50").to_bitarray
      expect(bits.size).to eq 51
      expect(bits[1]).to be_true
      expect(bits[3]).to be_true
      expect(bits[50]).to be_true
      expect(bits[0]).to be_false
      expect(bits[2]).to be_false
    end

    it "works for a crowded set" do
      expect(SparseRange(Int32).new(list: "0..8,10").to_bitstring).to eq "11111111101"
    end
  end

  describe "#count" do
    it "is invalidated by clear" do
      sparserange = SparseRange(Int32).new list: "1..10"
      expect(sparserange.count).to eq 10
      sparserange.clear
      expect(sparserange.empty?).to be_true
      expect(sparserange.count).to eq 0
    end

    it "is invalidated by sort!" do
      sparserange = SparseRange(Int32).new ranges: [1..2, 4..5], assert: false
      expect(sparserange.count).to eq 4
      sparserange.add 3
      expect(sparserange.count).to eq 5
    end

    it "does not wrap for wide ranges" do
      expect(SparseRange(Int32).new([0..Int32::MAX]).count).to eq 2147483648_u128
      expect(SparseRange(Int32).new([Int32::MIN..Int32::MAX]).count).to eq 4294967296_u128
    end

    it "compiles and works for every supported type" do
      expect(SparseRange(Int8).new([1_i8..3_i8]).count).to eq 3
      expect(SparseRange(UInt8).new([1_u8..3_u8]).count).to eq 3
      expect(SparseRange(Int16).new([1_i16..3_i16]).count).to eq 3
      expect(SparseRange(UInt16).new([1_u16..3_u16]).count).to eq 3
      expect(SparseRange(Int64).new([1_i64..3_i64]).count).to eq 3
      expect(SparseRange(UInt64).new([1_u64..3_u64]).count).to eq 3
      expect(SparseRange(Int128).new([1_i128..3_i128]).count).to eq 3
      expect(SparseRange(UInt128).new([1_u128..3_u128]).count).to eq 3
    end
  end

  describe "#span" do
    it "does not overflow across the full width of T" do
      expect(SparseRange(UInt8).new([0_u8..255_u8]).span).to eq 256
      expect(SparseRange(Int8).new([Int8::MIN..Int8::MAX]).span).to eq 256
      expect(SparseRange(Int32).new([Int32::MIN..Int32::MAX]).span).to eq 4294967296_u128
    end
  end

  describe "#invert" do
    it "inverts a set touching T::MIN" do
      expect(SparseRange(Int8).new([Int8::MIN..0_i8]).invert.ranges).to eq [1_i8..Int8::MAX]
    end

    it "inverts a set touching T::MAX" do
      expect(SparseRange(Int8).new([0_i8..Int8::MAX]).invert.ranges).to eq [Int8::MIN..(-1_i8)]
    end

    it "inverts the full domain to the empty set" do
      expect(SparseRange(Int8).new([Int8::MIN..Int8::MAX]).invert.empty?).to be_true
    end

    it "inverts the empty set to the full domain" do
      expect(SparseRange(Int8).new.invert.ranges).to eq [Int8::MIN..Int8::MAX]
    end

    it "round-trips" do
      sparserange = SparseRange(Int8).new list: "1..3,10..20"
      expect(sparserange.invert.invert.ranges).to eq sparserange.ranges
    end
  end

  describe "#invert!" do
    it "inverts in place" do
      sparserange = SparseRange(Int8).new [0_i8..Int8::MAX]
      sparserange.invert!
      expect(sparserange.ranges).to eq [Int8::MIN..(-1_i8)]
    end
  end

  describe "the integer width conversions" do
    it "converts when the values fit" do
      expect(SparseRange(Int32).new(list: "1..3,10..12").to_i64?.try(&.ranges)).to eq [1_i64..3_i64, 10_i64..12_i64]
      expect(SparseRange(Int32).new(list: "1..3").to_u16?.try(&.ranges)).to eq [1_u16..3_u16]
      expect(SparseRange(Int32).new(list: "1..3").to_u128?.try(&.ranges)).to eq [1_u128..3_u128]
    end

    it "returns the same set for the identity conversion" do
      expect(SparseRange(Int32).new(list: "1..3").to_i32?.try(&.ranges)).to eq [1..3]
    end

    it "returns nil when a value does not fit" do
      expect(SparseRange(Int32).new(list: "-5..-1").to_u32?).to be_nil
      expect(SparseRange(Int32).new(list: "-5..-1").to_u16?).to be_nil
      expect(SparseRange(Int64).new(list: "70000").to_u16?).to be_nil
    end

    it "converts the empty set" do
      expect(SparseRange(Int32).new.to_u64?.try(&.empty?)).to be_true
    end
  end

  describe "JSON" do
    it "round-trips" do
      sparserange = SparseRange(Int32).new list: "1..3,10..12"
      expect(SparseRange(Int32).from_json(sparserange.to_json).ranges).to eq sparserange.ranges
    end

    it "does not leak internal state" do
      sparserange = SparseRange(Int32).new list: "1..3"
      before = sparserange.to_json
      sparserange.count
      expect(sparserange.to_json).to eq before
      expect(before).to eq "[[1,3]]"
    end

    it "round-trips the empty set" do
      expect(SparseRange(Int32).from_json(SparseRange(Int32).new.to_json).empty?).to be_true
    end

    it "rejects malformed input" do
      expect { SparseRange(Int32).from_json "[[3,1]]" }.to raise_error(JSON::ParseException)
    end
  end

  describe "non-mutating operators" do
    it "leaves the receiver alone" do
      original = SparseRange(Int32).new list: "1..10"
      expect((original + (20..30)).ranges).to eq [1..10, 20..30]
      expect((original - (5..6)).ranges).to eq [1..4, 7..10]
      expect(original.ranges).to eq [1..10]
    end
  end

  describe "#dup" do
    it "produces an independent copy" do
      original = SparseRange(Int32).new list: "1..3,10..12"
      copy = original.dup
      copy.add 100
      expect(original.ranges).to eq [1..3, 10..12]
      expect(copy.ranges).to eq [1..3, 10..12, 100..100]
    end
  end

  describe "iterators" do
    it "exposes each and each_range without a block" do
      sparserange = SparseRange(Int32).new list: "1..3,10..11"
      expect(sparserange.each.to_a).to eq [1, 2, 3, 10, 11]
      expect(sparserange.each_range.to_a).to eq [1..3, 10..11]
    end
  end

  describe "the empty set" do
    it "raises IndexError for min, max and span" do
      empty = SparseRange(Int32).new
      expect { empty.min }.to raise_error(IndexError)
      expect { empty.max }.to raise_error(IndexError)
      expect { empty.span }.to raise_error(IndexError)
      expect(empty.min?).to be_nil
      expect(empty.max?).to be_nil
      expect(empty.span?).to be_nil
    end
  end

  describe "#crowded?" do
    it "accepts an explicit window" do
      sparserange = SparseRange(Int32).new list: "1,2,3"
      expect(sparserange.crowded?(0, 5)).to be_true
      expect(sparserange.crowded?(0, 9)).to be_false
    end
  end

  describe "the convenience constructors" do
    it "exist for every supported type, including 8-bit" do
      expect(SparseRange.new(Int8)).to be_a SparseRange(Int8)
      expect(SparseRange.new(UInt8)).to be_a SparseRange(UInt8)
      expect(SparseRange.new(Int128)).to be_a SparseRange(Int128)
      expect(SparseRange.new(UInt128)).to be_a SparseRange(UInt128)
    end

    it "forward named arguments" do
      expect(SparseRange.new(Int32, list: "1..5,7").ranges).to eq [1..5, 7..7]
      expect(SparseRange.new(Int32, ranges: [1..5, 10..12]).ranges).to eq [1..5, 10..12]
    end

    it "forward positional arguments" do
      expect(SparseRange.new(Int32, [1..5]).ranges).to eq [1..5]
    end
  end
end
