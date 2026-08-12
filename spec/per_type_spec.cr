require "./spec_helper"

# One behavioural suite, generated for every integer type the shard supports.
#
# This replaces the eight hand-written per-type files. Those covered
# Int8..UInt64 but not the 128-bit types, and none of them tested its own
# `T::MIN`/`T::MAX` — which is exactly where this class's bugs live, since
# `#pred` and `#succ` overflow there and `T::MIN` is zero for every unsigned
# type.
#
# Values are kept under 60 so that every fixture fits in `Int8`.

# Builds a `Range(T, T)` from plain integer literals.
macro rng(type, from, to)
  Range({{ type }}, {{ type }}).new({{ type }}.new({{ from }}), {{ type }}.new({{ to }}))
end

# Builds a `T` from a plain integer literal.
macro val(type, number)
  {{ type }}.new({{ number }})
end

{% for type in [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128] %}
  {% unsigned = type.name.starts_with?("U") %}
  {% wide = type.name.ends_with?("128") %}

  Spectator.describe SparseRange({{ type }}) do
    let(sparserange) { SparseRange({{ type }}).new [rng({{ type }}, 10, 19), rng({{ type }}, 30, 39)] }

    describe "construction" do
      it "can be created empty" do
        expect(SparseRange({{ type }}).new.ranges).to be_empty
        expect(SparseRange({{ type }}).new.empty?).to be_true
      end

      it "can be created from an array of ranges" do
        expect(sparserange.ranges).to eq [rng({{ type }}, 10, 19), rng({{ type }}, 30, 39)]
        expect(sparserange.size).to eq 2
      end

      it "can be created from a string" do
        expect(SparseRange({{ type }}).new(list: "1,3,5").ranges)
          .to eq [rng({{ type }}, 1, 1), rng({{ type }}, 3, 3), rng({{ type }}, 5, 5)]
        expect(SparseRange({{ type }}).new(list: "1..3,5").ranges)
          .to eq [rng({{ type }}, 1, 3), rng({{ type }}, 5, 5)]
        expect(SparseRange({{ type }}).new(list: "[1...5, 7]").ranges)
          .to eq [rng({{ type }}, 1, 4), rng({{ type }}, 7, 7)]
      end

      it "raises rather than silently returning an empty set" do
        expect { SparseRange({{ type }}).new(list: "garbage") }
          .to raise_error(SparseRange::ParseException)
        expect { SparseRange({{ type }}).new(list: "1,,2") }
          .to raise_error(SparseRange::ParseException)
      end

      it "sorts and coalesces when told not to assert" do
        expect(SparseRange({{ type }}).new([rng({{ type }}, 11, 20), rng({{ type }}, 1, 9),
                                            rng({{ type }}, 23, 30)], assert: false).ranges)
          .to eq [rng({{ type }}, 1, 9), rng({{ type }}, 11, 20), rng({{ type }}, 23, 30)]
        expect(SparseRange({{ type }}).new([rng({{ type }}, 1, 40), rng({{ type }}, 5, 10)],
                                           assert: false).ranges)
          .to eq [rng({{ type }}, 1, 40)]
      end

      it "rejects an unsorted or overlapping array by default" do
        expect { SparseRange({{ type }}).new ranges: [rng({{ type }}, 30, 39), rng({{ type }}, 1, 3)] }
          .to raise_error(SparseRange::AssertionError)
      end
    end

    describe "measurement" do
      it "reports min, max, span, count and size" do
        expect(sparserange.min).to eq val({{ type }}, 10)
        expect(sparserange.max).to eq val({{ type }}, 39)
        expect(sparserange.span).to eq 30
        expect(sparserange.count).to eq 20
        expect(sparserange.size).to eq 2
      end

      it "returns nil from the query forms when empty" do
        empty = SparseRange({{ type }}).new
        expect(empty.min?).to be_nil
        expect(empty.max?).to be_nil
        expect(empty.span?).to be_nil
        expect { empty.min }.to raise_error(IndexError)
      end

      it "recomputes the count after a change" do
        expect(sparserange.count).to eq 20
        sparserange.add val({{ type }}, 25)
        expect(sparserange.count).to eq 21
        sparserange.clear
        expect(sparserange.count).to eq 0
      end
    end

    describe "#add" do
      it "inserts before the first range" do
        sparserange.add val({{ type }}, 5)
        expect(sparserange.ranges)
          .to eq [rng({{ type }}, 5, 5), rng({{ type }}, 10, 19), rng({{ type }}, 30, 39)]
      end

      it "inserts into a gap" do
        sparserange.add val({{ type }}, 25)
        expect(sparserange.ranges)
          .to eq [rng({{ type }}, 10, 19), rng({{ type }}, 25, 25), rng({{ type }}, 30, 39)]
      end

      it "appends after the last range" do
        sparserange.add val({{ type }}, 50)
        expect(sparserange.ranges)
          .to eq [rng({{ type }}, 10, 19), rng({{ type }}, 30, 39), rng({{ type }}, 50, 50)]
      end

      it "extends a range forwards and backwards by abutting" do
        sparserange.add val({{ type }}, 20)
        expect(sparserange.ranges).to eq [rng({{ type }}, 10, 20), rng({{ type }}, 30, 39)]
        sparserange.add val({{ type }}, 9)
        expect(sparserange.ranges).to eq [rng({{ type }}, 9, 20), rng({{ type }}, 30, 39)]
      end

      it "ignores a value already present" do
        sparserange.add val({{ type }}, 15)
        expect(sparserange.ranges).to eq [rng({{ type }}, 10, 19), rng({{ type }}, 30, 39)]
      end

      it "coalesces two ranges when the gap is filled" do
        sparserange.add rng({{ type }}, 20, 29)
        expect(sparserange.ranges).to eq [rng({{ type }}, 10, 39)]
        expect(sparserange.size).to eq 1
      end

      it "absorbs several ranges at once" do
        sparserange.add rng({{ type }}, 50, 59)
        sparserange.add rng({{ type }}, 5, 55)
        expect(sparserange.ranges).to eq [rng({{ type }}, 5, 59)]
      end

      it "normalises exclusive ranges and drops empty ones" do
        expect(SparseRange({{ type }}).new.add(val({{ type }}, 5)...val({{ type }}, 10)).ranges)
          .to eq [rng({{ type }}, 5, 9)]
        expect(SparseRange({{ type }}).new.add(val({{ type }}, 5)...val({{ type }}, 5)).ranges)
          .to be_empty
      end

      it "rejects a reversed range" do
        expect { SparseRange({{ type }}).new.add rng({{ type }}, 10, 5) }
          .to raise_error(ArgumentError)
      end

      it "is order independent" do
        forward = SparseRange({{ type }}).new
          .add(rng({{ type }}, 1, 3), rng({{ type }}, 5, 7), rng({{ type }}, 9, 11))
        reverse = SparseRange({{ type }}).new
          .add(rng({{ type }}, 9, 11), rng({{ type }}, 5, 7), rng({{ type }}, 1, 3))
        expect(forward.ranges).to eq reverse.ranges
        expect(forward.assert?).to be_true
      end
    end

    describe "#subtract" do
      it "trims the head" do
        sparserange.subtract rng({{ type }}, 10, 12)
        expect(sparserange.ranges).to eq [rng({{ type }}, 13, 19), rng({{ type }}, 30, 39)]
      end

      it "trims the tail" do
        sparserange.subtract rng({{ type }}, 17, 19)
        expect(sparserange.ranges).to eq [rng({{ type }}, 10, 16), rng({{ type }}, 30, 39)]
      end

      it "splits a range in two" do
        sparserange.subtract val({{ type }}, 15)
        expect(sparserange.ranges)
          .to eq [rng({{ type }}, 10, 14), rng({{ type }}, 16, 19), rng({{ type }}, 30, 39)]
      end

      it "removes a range covered exactly" do
        sparserange.subtract rng({{ type }}, 10, 19)
        expect(sparserange.ranges).to eq [rng({{ type }}, 30, 39)]
      end

      it "removes several ranges at once" do
        sparserange.subtract rng({{ type }}, 5, 50)
        expect(sparserange.empty?).to be_true
      end

      it "never leaves a reversed range behind" do
        [rng({{ type }}, 10, 10), rng({{ type }}, 19, 19), rng({{ type }}, 10, 15),
         rng({{ type }}, 15, 19), rng({{ type }}, 30, 39)].each do |subtrahend|
          copy = sparserange.dup
          copy.subtract subtrahend
          expect(copy.assert?).to be_true
        end
      end
    end

    describe "iteration" do
      it "yields every value and every range" do
        expect(sparserange.each.to_a.size).to eq 20
        expect(sparserange.each_range.to_a).to eq sparserange.ranges
        expect(sparserange.each_range.to_a.size).to eq 2
      end

      it "yields the excluded values within a window" do
        result = [] of {{ type }}
        sparserange.each_excluded(val({{ type }}, 18), val({{ type }}, 31)) { |value| result << value }
        expect(result).to eq (val({{ type }}, 20)..val({{ type }}, 29)).to_a
      end

      it "yields the gaps between min and max by default" do
        result = [] of {{ type }}
        sparserange.each_excluded { |value| result << value }
        expect(result).to eq (val({{ type }}, 20)..val({{ type }}, 29)).to_a
      end
    end

    describe "conversion" do
      it "round-trips through JSON" do
        text = sparserange.to_json
        expect(SparseRange({{ type }}).from_json(text).ranges).to eq sparserange.ranges
      end

      it "widens to UInt128" do
        expect(sparserange.to_u128?.try(&.count)).to eq 20
      end

      it "renders a bitstring counting from zero" do
        bits = SparseRange({{ type }}).new([rng({{ type }}, 1, 3), rng({{ type }}, 5, 5)]).to_bitstring
        expect(bits).to eq "011101"
      end
    end

    describe "#crowded?" do
      it "decides against the set's own span" do
        # 20 of the 30 values between min and max
        expect(sparserange.crowded?).to be_true
        expect(SparseRange({{ type }}).new([rng({{ type }}, 1, 2), rng({{ type }}, 50, 50)]).crowded?)
          .to be_false
      end

      it "decides against an explicit span" do
        expect(sparserange.crowded?(val({{ type }}, 30))).to be_true
        expect(sparserange.crowded?(val({{ type }}, 41))).to be_false
      end

      it "decides against an explicit window" do
        expect(sparserange.crowded?(val({{ type }}, 10), val({{ type }}, 39))).to be_true
        expect(sparserange.crowded?(val({{ type }}, 0), val({{ type }}, 50))).to be_false
        expect(sparserange.crowded?(rng({{ type }}, 10, 39))).to be_true
        expect(sparserange.crowded?(rng({{ type }}, 0, 50))).to be_false
      end
    end

    describe "#invert!" do
      it "replaces the set with its complement in place" do
        edge = SparseRange({{ type }}).new [{{ type }}::MIN..val({{ type }}, 10)]
        edge.invert!
        expect(edge.ranges).to eq [val({{ type }}, 11)..{{ type }}::MAX]
        edge.invert!
        expect(edge.ranges).to eq [{{ type }}::MIN..val({{ type }}, 10)]
      end
    end

    describe "copying" do
      it "duplicates independently" do
        copy = sparserange.dup
        copy.add val({{ type }}, 50)
        expect(sparserange.ranges).to eq [rng({{ type }}, 10, 19), rng({{ type }}, 30, 39)]
        expect(copy.size).to eq 3
      end

      it "leaves the receiver alone under + and -" do
        expect((sparserange + val({{ type }}, 50)).size).to eq 3
        expect((sparserange - val({{ type }}, 15)).size).to eq 3
        expect(sparserange.ranges).to eq [rng({{ type }}, 10, 19), rng({{ type }}, 30, 39)]
      end
    end

    describe "the T::MIN and T::MAX boundaries" do
      it "adds a value at T::MIN without underflowing" do
        sparserange.add {{ type }}::MIN
        expect(sparserange.min).to eq {{ type }}::MIN
        expect(sparserange.assert?).to be_true
      end

      it "adds a value at T::MAX without overflowing" do
        sparserange.add {{ type }}::MAX
        expect(sparserange.max).to eq {{ type }}::MAX
        expect(sparserange.assert?).to be_true
      end

      it "coalesces a value abutting T::MIN" do
        edge = SparseRange({{ type }}).new [{{ type }}::MIN.succ..val({{ type }}, 50)]
        edge.add {{ type }}::MIN
        expect(edge.ranges).to eq [{{ type }}::MIN..val({{ type }}, 50)]
        expect(edge.size).to eq 1
      end

      it "coalesces a value abutting T::MAX" do
        edge = SparseRange({{ type }}).new [val({{ type }}, 50)..{{ type }}::MAX.pred]
        edge.add {{ type }}::MAX
        expect(edge.ranges).to eq [val({{ type }}, 50)..{{ type }}::MAX]
        expect(edge.size).to eq 1
      end

      it "subtracts at T::MIN without underflowing" do
        edge = SparseRange({{ type }}).new [{{ type }}::MIN..val({{ type }}, 50)]
        edge.subtract {{ type }}::MIN
        expect(edge.ranges).to eq [{{ type }}::MIN.succ..val({{ type }}, 50)]
      end

      it "subtracts at T::MAX without overflowing" do
        edge = SparseRange({{ type }}).new [val({{ type }}, 50)..{{ type }}::MAX]
        edge.subtract {{ type }}::MAX
        expect(edge.ranges).to eq [val({{ type }}, 50)..{{ type }}::MAX.pred]
      end

      it "adds a range reaching T::MAX" do
        edge = SparseRange({{ type }}).new [val({{ type }}, 10)..val({{ type }}, 20)]
        edge.add val({{ type }}, 21)..{{ type }}::MAX
        expect(edge.ranges).to eq [val({{ type }}, 10)..{{ type }}::MAX]
      end

      it "walks the excluded values up to T::MAX without overflowing" do
        edge = SparseRange({{ type }}).new [val({{ type }}, 0)..{{ type }}::MAX]
        count = 0
        edge.each_excluded { |_| count += 1 }
        expect(count).to eq 0
      end

      it "inverts the empty set to the whole domain, and back" do
        empty = SparseRange({{ type }}).new
        expect(empty.invert.ranges).to eq [{{ type }}::MIN..{{ type }}::MAX]
        expect(empty.invert.invert.empty?).to be_true
      end

      it "inverts a set touching both bounds" do
        edge = SparseRange({{ type }}).new [{{ type }}::MIN..val({{ type }}, 10)]
        expect(edge.invert.ranges).to eq [val({{ type }}, 11)..{{ type }}::MAX]
        expect(edge.invert.invert.ranges).to eq edge.ranges
      end

      {% if wide %}
        it "raises rather than reporting a wrong cardinality for the whole domain" do
          whole = SparseRange({{ type }}).new [{{ type }}::MIN..{{ type }}::MAX]
          expect { whole.count }.to raise_error(OverflowError)
          expect { whole.span }.to raise_error(OverflowError)
        end

        it "is exact one value below the whole domain" do
          almost = SparseRange({{ type }}).new [{{ type }}::MIN..{{ type }}::MAX.pred]
          expect(almost.count).to eq UInt128::MAX
        end
      {% else %}
        it "counts the whole domain exactly" do
          whole = SparseRange({{ type }}).new [{{ type }}::MIN..{{ type }}::MAX]
          expect(whole.count).to eq (1_u128 << (sizeof({{ type }}) * 8))
          expect(whole.span).to eq (1_u128 << (sizeof({{ type }}) * 8))
          expect(whole.size).to eq 1
        end
      {% end %}
    end

    {% if unsigned %}
      describe "unsigned specifics" do
        it "treats zero as T::MIN" do
          expect({{ type }}::MIN).to eq 0
          zero = SparseRange({{ type }}).new
          zero.add val({{ type }}, 0)
          expect(zero.ranges).to eq [rng({{ type }}, 0, 0)]
          expect(zero.min).to eq 0
        end

        it "subtracts zero from a range starting at zero" do
          zero = SparseRange({{ type }}).new [rng({{ type }}, 0, 5)]
          zero.subtract val({{ type }}, 0)
          expect(zero.ranges).to eq [rng({{ type }}, 1, 5)]
        end
      end
    {% else %}
      describe "signed specifics" do
        let(negatives) do
          SparseRange({{ type }}).new [rng({{ type }}, -19, -10), rng({{ type }}, 10, 19)]
        end

        it "holds negative values" do
          expect(negatives.min).to eq val({{ type }}, -19)
          expect(negatives.max).to eq val({{ type }}, 19)
          expect(negatives.count).to eq 20
        end

        it "coalesces across zero" do
          negatives.add rng({{ type }}, -9, 9)
          expect(negatives.ranges).to eq [rng({{ type }}, -19, 19)]
        end

        it "parses negative values from a string" do
          expect(SparseRange({{ type }}).new(list: "-5..-1,3").ranges)
            .to eq [rng({{ type }}, -5, -1), rng({{ type }}, 3, 3)]
        end

        it "refuses to build a bitstring from negative values" do
          expect { negatives.to_bitstring }.to raise_error(ArgumentError)
        end
      end
    {% end %}
  end
{% end %}
