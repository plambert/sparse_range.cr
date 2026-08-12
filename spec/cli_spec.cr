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
  raise "expected #{arguments.join(' ')} to raise a CLIError"
rescue error : SparseRange::CLI::CLIError
  error.message.to_s
end

Spectator.describe SparseRange::CLI do
  describe "parsing" do
    it "accepts integers and both range spellings" do
      expect(run("1", "2", "3", "5..10")).to eq "1..3,5..10\n"
      expect(run("5-10", "12")).to eq "5..10,12\n"
      expect(run("1...5")).to eq "1..4\n"
      expect(run("-5", "-3")).to eq "-5,-3\n"
    end

    it "coalesces overlapping and adjacent input" do
      expect(run("1..5", "6..9", "3..4")).to eq "1..9\n"
    end

    it "treats everything after -- as a value" do
      expect(run("--", "-5", "-3")).to eq "-5,-3\n"
    end

    it "rejects a value that does not fit in Int64" do
      expect(error_from("99999999999999999999")).to contain "does not fit"
      expect(error_from("1-99999999999999999999")).to contain "does not fit"
    end

    it "rejects a reversed range" do
      expect(error_from("10-5")).to contain "range end precedes range start"
      expect(error_from("10..5")).to contain "range end precedes range start"
    end

    it "rejects an unknown option and a non-numeric argument" do
      expect(error_from("--bogus")).to contain "unknown option"
      expect(error_from("1-2-3")).to contain "not an integer or range"
    end

    it "rejects a missing option argument" do
      expect(error_from("--delimiter")).to contain "expected an argument"
      expect(error_from("--left-bracket")).to contain "expected an argument"
    end

    it "does not overflow when coalescing at Int64::MAX" do
      expect(run("9223372036854775806", "9223372036854775807")).to eq "9223372036854775806..9223372036854775807\n"
    end
  end

  describe "--list" do
    it "is the default, and expands under --each" do
      expect(run("1", "2", "3", "5..10")).to eq "1..3,5..10\n"
      expect(run("--each", "1", "2", "3", "5..10")).to eq "1,2,3,5,6,7,8,9,10\n"
    end

    it "honours --lines" do
      expect(run("--lines", "1..3", "5..7")).to eq "1..3\n5..7\n"
      expect(run("--lines", "--each", "1..3")).to eq "1\n2\n3\n"
    end

    it "honours --delimiter in both spellings" do
      expect(run("--delimiter", ";", "1", "5..7")).to eq "1;5..7\n"
      expect(run("--delimiter=;", "1", "5..7")).to eq "1;5..7\n"
    end

    it "honours the bracket options" do
      expect(run("--brackets", "1", "5")).to eq "[1,5]\n"
      expect(run("--curly-brackets", "1", "5")).to eq "{1,5}\n"
      expect(run("--brackets=<>", "1", "5")).to eq "<1,5>\n"
      expect(run("--parens", "1", "5")).to eq "(1,5)\n"
    end

    it "applies left and right brackets independently, in either order" do
      expect(run("--left-bracket", "<", "--right-bracket", ">", "1", "5")).to eq "<1,5>\n"
      expect(run("--right-bracket", ">", "--left-bracket", "<", "1", "5")).to eq "<1,5>\n"
      expect(run("--left-bracket", "<", "1", "5")).to eq "<1,5\n"
    end

    it "rejects a --brackets= pair that is not two characters" do
      expect(error_from("--brackets=abc")).to contain "exactly two characters"
      expect(error_from("--brackets=")).to contain "exactly two characters"
    end

    it "prints nothing for an empty set" do
      expect(run_empty).to eq "\n"
      expect(run("--lines")).to eq ""
    end
  end

  describe "--json" do
    it "emits valid JSON in compact mode" do
      expect(run("--json", "1", "2", "3", "5..10")).to eq "[[1,3],[5,10]]\n"
      expect(JSON.parse(run("--json", "1", "2", "3", "5..10")).as_a.size).to eq 2
    end

    it "emits valid JSON under --each" do
      expect(run("--json", "--each", "1..3", "5")).to eq "[1,2,3,5]\n"
    end

    it "emits valid JSON for an empty set" do
      expect(run("--json")).to eq "[]\n"
    end

    it "ignores the delimiter and bracket options" do
      expect(run("--json", "--delimiter", ";", "1", "5")).to eq "[[1,1],[5,5]]\n"
      expect(run("--json", "--curly-brackets", "1", "5")).to eq "[[1,1],[5,5]]\n"
    end

    it "round-trips through SparseRange" do
      text = run("--json", "1..3", "10..12")
      expect(SparseRange(Int64).from_json(text).ranges).to eq [1_i64..3_i64, 10_i64..12_i64]
    end
  end

  describe "--bits" do
    it "counts from zero up to the maximum" do
      expect(run("--bits", "0", "5")).to eq "100001\n"
      expect(run("--bits", "3", "7")).to eq "00010001\n"
      expect(run("--bits", "5")).to eq "000001\n"
      expect(run("--bits", "0")).to eq "1\n"
    end

    it "handles a crowded set" do
      expect(run("--bits", "0..8", "10")).to eq "11111111101\n"
    end

    it "rejects negative values rather than printing something misleading" do
      expect(error_from("--bits", "-1")).to contain "negative"
    end

    it "rejects a set too wide to render" do
      expect(error_from("--bits", "4000000000")).to contain "more than a BitArray can hold"
    end
  end

  describe "--help and --version" do
    it "prints help and stops parsing" do
      output = run("--help", "--bogus")
      expect(output).to contain "Usage:"
      expect(output).to contain "--brackets=LR"
    end

    it "prints the version from shard.yml" do
      expect(run("--version")).to contain SparseRange::VERSION
    end

    it "documents every option it accepts" do
      help = run("--help")
      %w[--list --json --bits --compact --each --lines --delimiter --brackets
        --no-brackets --left-bracket --right-bracket --square-brackets
        --round-brackets --parens --angle-brackets --curly-brackets --help
        --version --one-line --ranges --all --every --no-lines].each do |option|
        expect(help).to contain option
      end
    end
  end
end
