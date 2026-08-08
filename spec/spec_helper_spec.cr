require "./spec_helper"

# These helpers exist for debugging by hand, but they are part of the build, so
# they need at least enough coverage to keep them compiling.
describe "spec_helper" do
  describe "fixture" do
    it "builds a SparseRange from each fixture" do
      FIXTURES.each_index do |index|
        fixture(index).should be_a SparseRange(Int32)
      end
      fixture(3).empty?.should be_true
    end
  end

  describe "compare_ranges" do
    it "renders a bit grid for each named list" do
      output = IO::Memory.new
      compare_ranges [{"before", [1..5]}, {"after", [1..3, 5..5]}], output
      text = output.to_s
      text.should contain "before"
      text.should contain "after"
      text.should contain "*****"
      text.should contain "***-*"
    end

    it "splits wide ranges into windows" do
      output = IO::Memory.new
      compare_ranges [{"wide", [1..10]}], output, window_size: 4
      output.to_s.lines.count(&.starts_with?("wide")).should eq 4
    end
  end
end
