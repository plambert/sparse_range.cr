require "./spec_helper"

describe SparseRange do
  it "exposes the version from shard.yml" do
    SparseRange::VERSION.should match /\A\d+\.\d+\.\d+/
  end

  it "creates a SparseRange for every supported integer type" do
    SparseRange.new(Int8).should be_a SparseRange(Int8)
    SparseRange.new(UInt8).should be_a SparseRange(UInt8)
    SparseRange.new(Int16).should be_a SparseRange(Int16)
    SparseRange.new(UInt16).should be_a SparseRange(UInt16)
    SparseRange.new(Int32).should be_a SparseRange(Int32)
    SparseRange.new(UInt32).should be_a SparseRange(UInt32)
    SparseRange.new(Int64).should be_a SparseRange(Int64)
    SparseRange.new(UInt64).should be_a SparseRange(UInt64)
    SparseRange.new(Int128).should be_a SparseRange(Int128)
    SparseRange.new(UInt128).should be_a SparseRange(UInt128)
  end

  it "compiles the whole public API for a representative signed and unsigned type" do
    {% for type in [Int8, UInt8, Int16, UInt16, Int64, UInt64, Int128, UInt128] %}
      one = {{ type }}.new 1
      sparserange = SparseRange({{ type }}).new list: [one..{{ type }}.new(10)]
      sparserange.add {{ type }}.new(20)
      sparserange.subtract {{ type }}.new(5)
      sparserange.count.should eq 10
      sparserange.span.should eq 20
      sparserange.size.should eq 3
      sparserange.min.should eq 1
      sparserange.max.should eq 20
      sparserange.empty?.should be_false
      sparserange.assert?.should be_true
      sparserange.crowded?.should be_true # 10 of 20 values is exactly half
      sparserange.each.to_a.size.should eq 10
      sparserange.each_range.to_a.size.should eq 3
      sparserange.to_bitstring.size.should eq 21
      sparserange.dup.ranges.should eq sparserange.ranges
      (sparserange + {{ type }}.new(100)).count.should eq 11
      (sparserange - one).count.should eq 9
      SparseRange({{ type }}).from_json(sparserange.to_json).ranges.should eq sparserange.ranges
      sparserange.to_u128?.try(&.count).should eq 10
      sparserange.invert!.empty?.should be_false
      sparserange.clear.count.should eq 0
    {% end %}
  end
end
