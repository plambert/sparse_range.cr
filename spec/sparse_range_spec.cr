require "./spec_helper"

# Behaviour that is not per-type lives here; everything that should hold for
# every element type is generated in spec/per_type_spec.cr.
Spectator.describe SparseRange do
  it "exposes the version from shard.yml" do
    expect(SparseRange::VERSION).to match /\A\d+\.\d+\.\d+/
  end

  it "provides a convenience constructor for every supported integer type" do
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

  it "forwards positional and named arguments through the convenience constructor" do
    expect(SparseRange.new(Int32, [1..5]).ranges).to eq [1..5]
    expect(SparseRange.new(Int32, list: "1..5,7").ranges).to eq [1..5, 7..7]
    expect(SparseRange.new(Int32, ranges: [1..5, 10..12]).ranges).to eq [1..5, 10..12]
  end

  it "takes the element type from the class argument, not the receiver" do
    expect(SparseRange(Int64).new(Int32)).to be_a SparseRange(Int32)
  end
end
