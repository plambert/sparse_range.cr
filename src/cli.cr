# Command line front end for `SparseRange`.

require "json"
require "./sparse_range"

class SparseRange(T)
  # Command line front end for `SparseRange`, building a `SparseRange(Int64)`
  # from its arguments and printing it in one of several formats.
  class CLI
    # Raised for any condition that should be reported to the user as a plain
    # error message rather than a stack trace.
    class CLIError < Exception; end

    # How `#run` renders the set.
    enum OutputFormat
      # A delimited list of integers and ranges.
      List
      # A JSON array.
      JSON
      # A string of `'0'` and `'1'` characters, one per value from zero to the
      # maximum.
      Bits
    end

    # The arguments this instance was constructed with.
    property argv : Array(String)

    # How `#run` renders the set. Defaults to `OutputFormat::List`.
    property output_format : OutputFormat = OutputFormat::List

    # The set built from the value arguments.
    property sparse_range : SparseRange(Int64) = SparseRange(Int64).new

    # The opening bracket, or `nil` to use the output format's default.
    property left_bracket : String? = nil

    # The closing bracket, or `nil` to use the output format's default.
    property right_bracket : String? = nil

    # When true, print one entry per line instead of one delimited line.
    property? lines = false

    # When true, expand ranges to their individual values.
    property? each = false

    # When true, `#run` prints the usage message and returns.
    property? help = false

    # When true, `#run` prints the version and returns.
    property? version = false

    # The separator printed between entries.
    property delimiter : String = ","

    # Parses *argv*, building `#sparse_range` and setting the output options.
    #
    # Raises `CLIError` for any malformed argument. Stops as soon as `--help` or
    # `--version` is seen, so those always work regardless of what follows.
    def initialize(@argv = ARGV.dup)
      arguments = @argv.dup
      only_values = false
      while argument = arguments.shift?
        if only_values
          parse_value argument
        elsif argument == "--"
          only_values = true
        elsif argument.starts_with?('-') && !value?(argument)
          parse_option argument, arguments
        else
          parse_value argument
        end
        return if help? || version?
      end
    end

    # Returns the stored ranges.
    def ranges
      @sparse_range.ranges
    end

    # The bracket pair actually used for the selected format.
    def brackets : {String, String}
      default_left, default_right = case output_format
                                    in .list? then {"", ""}
                                    in .json? then {"[", "]"}
                                    in .bits? then {"", ""}
                                    end
      {@left_bracket || default_left, @right_bracket || default_right}
    end

    private def value?(argument : String) : Bool
      !!(argument =~ /\A[-+]?[0-9]+([-.]|\z)/)
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def parse_option(option : String, arguments : Array(String)) : Nil
      case option
      when "--help", "-h"              then @help = true
      when "--version", "-V"           then @version = true
      when "--delimiter"               then @delimiter = argument_for option, arguments
      when "--left-bracket"            then @left_bracket = argument_for option, arguments
      when "--right-bracket"           then @right_bracket = argument_for option, arguments
      when "--brackets", "--[]", "-[]" then set_brackets "[", "]"
      when "--no-brackets"             then set_brackets "", ""
      when "--square-brackets"         then set_brackets "[", "]"
      when "--round-brackets", "--parentheses",
           "--parens" then set_brackets "(", ")"
      when "--angle-brackets"            then set_brackets "<", ">"
      when "--curly-brackets"            then set_brackets "{", "}"
      when "--lines"                     then @lines = true
      when "--no-lines", "--one-line"    then @lines = false
      when "--compact", "--ranges"       then @each = false
      when "--each", "--all", "--every"  then @each = true
      when "--list"                      then @output_format = OutputFormat::List
      when "--json"                      then @output_format = OutputFormat::JSON
      when "--bits"                      then @output_format = OutputFormat::Bits
      when .starts_with?("--delimiter=") then @delimiter = option.split('=', 2)[1]
      when .starts_with?("--brackets=")
        pair = option.split('=', 2)[1]
        unless pair.size == 2
          raise CLIError.new "#{option}: --brackets= needs exactly two characters"
        end
        set_brackets pair[0].to_s, pair[1].to_s
      else
        raise CLIError.new "#{option}: unknown option"
      end
    end

    private def set_brackets(left : String, right : String) : Nil
      @left_bracket = left
      @right_bracket = right
    end

    private def argument_for(option : String, arguments : Array(String)) : String
      arguments.shift? || raise CLIError.new "#{option}: expected an argument"
    end

    private def parse_value(argument : String) : Nil
      case argument
      when /\A([-+]?[0-9]+)\z/
        sparse_range << to_i64($1, argument)
      when /\A([-+]?[0-9]+)\.\.\.([-+]?[0-9]+)\z/
        add_range to_i64($1, argument), to_i64($2, argument), argument, exclusive: true
      when /\A([-+]?[0-9]+)(?:-|\.\.)([-+]?[0-9]+)\z/
        add_range to_i64($1, argument), to_i64($2, argument), argument, exclusive: false
      else
        raise CLIError.new "#{argument}: not an integer or range"
      end
    end

    private def add_range(from : Int64, to : Int64, argument : String, exclusive : Bool) : Nil
      raise CLIError.new "#{argument}: range end precedes range start" if from > to
      sparse_range << Range(Int64, Int64).new(from, to, exclusive)
    end

    private def to_i64(text : String, argument : String) : Int64
      text.to_i64? || raise CLIError.new "#{argument}: #{text} does not fit in a 64-bit integer"
    end

    # Writes the usage message to *io*.
    def print_help(io = STDOUT) : Nil
      io.puts <<-HELP
        Usage: #{PROGRAM} [options] [--] [INTEGER|RANGE ...]

        Build a sparse set of Int64 ranges from the arguments and print it.
        Adjacent and overlapping inputs are coalesced.

        Inputs:
          N           single integer (e.g. 5, -3)
          A-B, A..B   inclusive range
          A...B       exclusive range (B is not included)
          --          treat every remaining argument as a value, not an option

        Output format:
          --list                       print as a list (default)
          --json                       print as JSON
          --bits                       print as a 0/1 bitstring from 0 to the maximum

        Layout:
          --compact, --ranges          print coalesced ranges (default)
          --each, --all, --every       expand to individual integers
          --lines                      one entry per line
          --no-lines, --one-line       all entries on one line (default)
          --delimiter STR              separator between entries (default ",")
          --delimiter=STR              same, as a single argument

        Brackets:
          --brackets, --[], -[]        enclose output in [ ]
          --no-brackets                no brackets
          --brackets=LR                use the two-char pair LR (e.g. --brackets=<>)
          --left-bracket STR           set just the left bracket
          --right-bracket STR          set just the right bracket
          --square-brackets            [ ]
          --round-brackets, --parens   ( )
          --angle-brackets             < >
          --curly-brackets             { }

        Other:
          -h, --help                   show this help and exit
          -V, --version                show the version and exit

        Notes:
          --json always emits valid JSON: an array of [begin, end] pairs, or a
          flat array of integers under --each. It ignores --delimiter and the
          bracket options.

          --bits counts from zero, so it rejects a set containing negative
          values. --lines and --each have no effect on it.

        Examples:
          #{PROGRAM} 1 2 3 5..10            # 1..3,5..10
          #{PROGRAM} --each 1 2 3 5..10     # 1,2,3,5,6,7,8,9,10
          #{PROGRAM} --json 1..3 5          # [[1,3],[5,5]]
          #{PROGRAM} --json --each 1..3 5   # [1,2,3,5]
          #{PROGRAM} --bits 0 5             # 100001
        HELP
    end

    # Parses the arguments and writes the result to *io*.
    def run(io : IO = STDOUT) : Nil
      if help?
        print_help io
        return
      end
      if version?
        io.puts "#{PROGRAM} #{SparseRange::VERSION}"
        return
      end

      case output_format
      in .list? then print_list io
      in .json? then print_json io
      in .bits? then print_bits io
      end
    end

    private def print_list(io : IO) : Nil
      left, right = brackets
      if lines?
        if each?
          @sparse_range.each { |value| io.puts value }
        else
          ranges.each do |range|
            print_range range, io
            io << '\n'
          end
        end
      else
        io << left
        next_delimiter = ""
        if each?
          @sparse_range.each do |value|
            io << next_delimiter
            next_delimiter = delimiter
            io << value
          end
        else
          ranges.each do |range|
            io << next_delimiter
            next_delimiter = delimiter
            print_range range, io
          end
        end
        io << right << '\n'
      end
    end

    private def print_json(io : IO) : Nil
      if each?
        JSON.build(io) do |json|
          json.array do
            @sparse_range.each { |value| json.number value }
          end
        end
      else
        @sparse_range.to_json io
      end
      io << '\n'
    end

    private def print_bits(io : IO) : Nil
      @sparse_range.to_bitstring io
      io << '\n'
    rescue error : ArgumentError
      raise CLIError.new error.message || "cannot render this set as a bitstring"
    end

    private def print_range(range : Range(Int64, Int64), io : IO) : Nil
      if range.begin == range.end
        io << range.begin
      else
        io << range
      end
    end
  end
end

PROGRAM = File.basename PROGRAM_NAME
