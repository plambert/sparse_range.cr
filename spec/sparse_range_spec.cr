require "./spec_helper"

Spectator.describe SparseRange do
  it "exposes the version from shard.yml" do
    expect(SparseRange::VERSION).to match /\A\d+\.\d+\.\d+/
  end

  it "creates a SparseRange for every supported integer type" do
    expect(SparseRange.new(Int8)).to be_a SparseRange(Int8)
    expect(SparseRange.new(UInt8)).to be_a SparseRange(UInt8)
    expect(SparseRange.new(Int16)).to be_a SparseRange(Int16)
    expect(SparseRange.new(UInt16)).to be_a SparseRange(UInt16)
    expect(SparseRange.new(Int32)).to be_a SparseRange(Int32)
    expect(SparseRange.new(UInt32)).to be_a SparseRange(UInt32)
    expect(SparseRange.new(Int64)).to be_a SparseRange(Int64)
    expect(SparseRange.new(UInt64)).to be_a SparseRange(UInt64)
    expect(SparseRange.new(Int128)).to be_a SparseRange(Int128)
    expect(SparseRange.new(UInt128)).to be_a SparseRange(UInt128)
  end

  it "compiles the whole public API for a representative signed and unsigned type" do
    {% for type in [Int8, UInt8, Int16, UInt16, Int64, UInt64, Int128, UInt128] %}
      one = {{ type }}.new 1
      sparserange = SparseRange({{ type }}).new list: [one..{{ type }}.new(10)]
      sparserange.add {{ type }}.new(20)
      sparserange.subtract {{ type }}.new(5)
      expect(sparserange.count).to eq 10
      expect(sparserange.span).to eq 20
      expect(sparserange.size).to eq 3
      expect(sparserange.min).to eq 1
      expect(sparserange.max).to eq 20
      expect(sparserange.empty?).to be_false
      expect(sparserange.assert?).to be_true
      expect(sparserange.crowded?).to be_true # 10 of 20 values is exactly half
      expect(sparserange.each.to_a.size).to eq 10
      expect(sparserange.each_range.to_a.size).to eq 3
      expect(sparserange.to_bitstring.size).to eq 21
      expect(sparserange.dup.ranges).to eq sparserange.ranges
      expect((sparserange + {{ type }}.new(100)).count).to eq 11
      expect((sparserange - one).count).to eq 9
      expect(SparseRange({{ type }}).from_json(sparserange.to_json).ranges).to eq sparserange.ranges
      expect(sparserange.to_u128?.try(&.count)).to eq 10
      expect(sparserange.invert!.empty?).to be_false
      expect(sparserange.clear.count).to eq 0
    {% end %}
  end
end
