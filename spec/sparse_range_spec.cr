require "./spec_helper"

describe SparseRange do
  it "can create a SparseRange(Int32)" do
    srange = SparseRange.new(Int32)
    srange.should be_a SparseRange(Int32)
  end
end
