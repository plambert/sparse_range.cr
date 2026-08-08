require "./spec_helper"
require "../src/cli"

private def run(*arguments : String) : String
  output = IO::Memory.new
  SparseRange::CLI.new(arguments.to_a).run output
  output.to_s
end

private def run_empty : String
  output = IO::Memory.new
  SparseRange::CLI.new(%w[]).run output
  output.to_s
end

private def error_from(*arguments : String) : String
  run(*arguments)
  fail "expected #{arguments.join(' ')} to raise a CLIError"
rescue error : SparseRange::CLI::CLIError
  error.message.to_s
end

describe SparseRange::CLI do
  describe "parsing" do
    it "accepts integers and both range spellings" do
      run("1", "2", "3", "5..10").should eq "1..3,5..10\n"
      run("5-10", "12").should eq "5..10,12\n"
      run("1...5").should eq "1..4\n"
      run("-5", "-3").should eq "-5,-3\n"
    end

    it "coalesces overlapping and adjacent input" do
      run("1..5", "6..9", "3..4").should eq "1..9\n"
    end

    it "treats everything after -- as a value" do
      run("--", "-5", "-3").should eq "-5,-3\n"
    end

    it "rejects a value that does not fit in Int64" do
      error_from("99999999999999999999").should contain "does not fit"
      error_from("1-99999999999999999999").should contain "does not fit"
    end

    it "rejects a reversed range" do
      error_from("10-5").should contain "range end precedes range start"
      error_from("10..5").should contain "range end precedes range start"
    end

    it "rejects an unknown option and a non-numeric argument" do
      error_from("--bogus").should contain "unknown option"
      error_from("1-2-3").should contain "not an integer or range"
    end

    it "rejects a missing option argument" do
      error_from("--delimiter").should contain "expected an argument"
      error_from("--left-bracket").should contain "expected an argument"
    end

    it "does not overflow when coalescing at Int64::MAX" do
      run("9223372036854775806", "9223372036854775807")
        .should eq "9223372036854775806..9223372036854775807\n"
    end
  end

  describe "--list" do
    it "is the default, and expands under --each" do
      run("1", "2", "3", "5..10").should eq "1..3,5..10\n"
      run("--each", "1", "2", "3", "5..10").should eq "1,2,3,5,6,7,8,9,10\n"
    end

    it "honours --lines" do
      run("--lines", "1..3", "5..7").should eq "1..3\n5..7\n"
      run("--lines", "--each", "1..3").should eq "1\n2\n3\n"
    end

    it "honours --delimiter in both spellings" do
      run("--delimiter", ";", "1", "5..7").should eq "1;5..7\n"
      run("--delimiter=;", "1", "5..7").should eq "1;5..7\n"
    end

    it "honours the bracket options" do
      run("--brackets", "1", "5").should eq "[1,5]\n"
      run("--curly-brackets", "1", "5").should eq "{1,5}\n"
      run("--brackets=<>", "1", "5").should eq "<1,5>\n"
      run("--parens", "1", "5").should eq "(1,5)\n"
    end

    it "applies left and right brackets independently, in either order" do
      run("--left-bracket", "<", "--right-bracket", ">", "1", "5").should eq "<1,5>\n"
      run("--right-bracket", ">", "--left-bracket", "<", "1", "5").should eq "<1,5>\n"
      run("--left-bracket", "<", "1", "5").should eq "<1,5\n"
    end

    it "rejects a --brackets= pair that is not two characters" do
      error_from("--brackets=abc").should contain "exactly two characters"
      error_from("--brackets=").should contain "exactly two characters"
    end

    it "prints nothing for an empty set" do
      run_empty.should eq "\n"
      run("--lines").should eq ""
    end
  end

  describe "--json" do
    it "emits valid JSON in compact mode" do
      run("--json", "1", "2", "3", "5..10").should eq "[[1,3],[5,10]]\n"
      JSON.parse(run("--json", "1", "2", "3", "5..10")).as_a.size.should eq 2
    end

    it "emits valid JSON under --each" do
      run("--json", "--each", "1..3", "5").should eq "[1,2,3,5]\n"
    end

    it "emits valid JSON for an empty set" do
      run("--json").should eq "[]\n"
    end

    it "ignores the delimiter and bracket options" do
      run("--json", "--delimiter", ";", "1", "5").should eq "[[1,1],[5,5]]\n"
      run("--json", "--curly-brackets", "1", "5").should eq "[[1,1],[5,5]]\n"
    end

    it "round-trips through SparseRange" do
      text = run("--json", "1..3", "10..12")
      SparseRange(Int64).from_json(text).ranges.should eq [1_i64..3_i64, 10_i64..12_i64]
    end
  end

  describe "--bits" do
    it "counts from zero up to the maximum" do
      run("--bits", "0", "5").should eq "100001\n"
      run("--bits", "3", "7").should eq "00010001\n"
      run("--bits", "5").should eq "000001\n"
      run("--bits", "0").should eq "1\n"
    end

    it "handles a crowded set" do
      run("--bits", "0..8", "10").should eq "11111111101\n"
    end

    it "rejects negative values rather than printing something misleading" do
      error_from("--bits", "-1").should contain "negative"
    end

    it "rejects a set too wide to render" do
      error_from("--bits", "4000000000").should contain "more than a BitArray can hold"
    end
  end

  describe "--help and --version" do
    it "prints help and stops parsing" do
      output = run("--help", "--bogus")
      output.should contain "Usage:"
      output.should contain "--brackets=LR"
    end

    it "prints the version from shard.yml" do
      run("--version").should contain SparseRange::VERSION
    end

    it "documents every option it accepts" do
      help = run("--help")
      %w[--list --json --bits --compact --each --lines --delimiter --brackets
        --no-brackets --left-bracket --right-bracket --square-brackets
        --round-brackets --parens --angle-brackets --curly-brackets --help
        --version --one-line --ranges --all --every --no-lines].each do |option|
        help.should contain option
      end
    end
  end
end
