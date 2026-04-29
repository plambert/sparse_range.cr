# CLI tool for SparseRange

require "json"
require "./sparse_range"

class SparseRange
  class CLI
    class CLIError < Exception; end

    enum OutputFormat
      List
      JSON
      BitVector
    end

    property argv : Array(String)
    property output_format : OutputFormat = OutputFormat::List
    property sparse_range : SparseRange(Int64) = SparseRange(Int64).new
    property brackets : {String, String} = {"", ""}
    property? lines = false
    property? each = false
    property? json_string = false
    property delimiter : String = ","

    def initialize(@argv = ARGV.dup)
      opts = @argv.dup
      _brackets : {String, String}? = nil
      while opt = opts.shift?
        case opt
        when "--help", "-h"
          raise CLIError.new "#{opt}: help not implemented yet"
        when "--delimiter"
          @delimiter = (opts.shift? || raise ArgumentError.new "#{opt}: expected an argument")
        when "--brackets", "--[]", "-[]"
          _brackets = {"[", "]"}
        when "--no-brackets"
          _brackets = {"", ""}
        when %r{^--brackets=(.)(.)$}
          _brackets = {$1, $2}
        when "--left-bracket"
          left_bracket = (opts.shift? || raise ArgumentError.new "#{opt}: expected an argument")
          _brackets = {left_bracket, _brackets ? _brackets[1] : ""}
        when "--right-bracket"
          right_bracket = (opts.shift? || raise ArgumentError.new "#{opt}: expected an argument")
          _brackets = {_brackets ? _brackets[0] : "", right_bracket}
        when "--square-brackets"
          _brackets = {"[", "]"}
        when "--round-brackets", "--parentheses", "--parens"
          _brackets = {"(", ")"}
        when "--angle-brackets"
          _brackets = {"<", ">"}
        when "--curly-brackets"
          _brackets = {"{", "}"}
        when "--lines"
          @lines = true
        when "--no-lines", "--one-line"
          @lines = false
        when "--compact", "--ranges"
          @each = false
        when "--each", "--all", "--every"
          @each = true
        when "--list"
          @output_format = OutputFormat::List
          _brackets ||= {"", ""}
        when "--json"
          @output_format = OutputFormat::JSON
          _brackets ||= {"[", "]"}
        when "--bits"
          @output_format = OutputFormat::BitVector
          _brackets ||= {"", ""}
        when %r{^[-+]?[0-9]+$}
          rg = opt.to_i64
          # STDERR.puts rg.inspect
          sparse_range << rg
        when %r{^([-+]?[0-9]+)(?:-|\.\.)([-+]?[0-9]+)$}
          rg = $1.to_i64..$2.to_i64
          # STDERR.puts rg.inspect
          sparse_range << rg
        when %r{^([-+]?[0-9]+)\.\.\.([-+]?[0-9]+)$}
          rg = $1.to_i64...$2.to_i64
          # STDERR.puts rg.inspect
          sparse_range << rg
        else
          raise CLIError.new "#{opt}: unknown option"
        end
      end

      @brackets = _brackets || {"", ""}
    end

    def ranges
      @sparse_range.ranges
    end

    private def print_range(rng, io = STDOUT)
      return unless rng.responds_to? :begin && rng.responds_to? :end
      if rng.begin == rng.end
        io << rng.begin
      else
        io << rng
      end
    end

    def run
      io = STDOUT

      case output_format
      in SparseRange::CLI::OutputFormat::List
        if @sparse_range.empty?
          STDERR.puts "(empty)"
        else
          if @lines
            if @each
              # lines=true each=true        --> every int on its own line
              @sparse_range.each do |int|
                io.puts int
              end
            else
              # lines=true each=false       --> every range on its own line
              if ranges.size > 0
                ranges.each do |rng|
                  print_range rng, io
                  io << '\n'
                end
              end
            end
          elsif @each
            # lines=false each=true         --> every int on a single line
            io << @brackets[0]
            iter = @sparse_range.each
            io << iter.next
            iter.each do |int|
              io << delimiter
              io << int
            end
            io << @brackets[1]
            io << '\n'
          else
            # lines=false each=false        --> every range on a single line
            io << @brackets[0]
            next_delimiter = ""
            ranges.each do |range|
              io << next_delimiter
              next_delimiter = delimiter
              print_range range, io
            end
            io << @brackets[1]
            io << '\n'
          end
        end
      in SparseRange::CLI::OutputFormat::JSON
        io << @brackets[0]
        if @each
          next_delimiter = ""
          @sparse_range.each do |int|
            io << next_delimiter
            next_delimiter = delimiter
            io << int
          end
        else
          next_delimiter = ""
          ranges.each do |range|
            io << next_delimiter
            next_delimiter = delimiter
            print_range range, io
          end
        end
        io << @brackets[1]
        io << '\n'
      in SparseRange::CLI::OutputFormat::BitVector
        if idx = @sparse_range.min?
          idx.times { io << '0' }
          ranges.each do |range|
            rbegin = range.begin
            if rbegin > idx
              (idx...rbegin).each { io << '0' }
            end
            range.each { io << '1' }
            idx = range.end + 1
          end
          io << '\n'
        else
          io.puts "0"
        end
      end
    end
  end
end

begin
  cli = SparseRange::CLI.new
  cli.run
rescue e : SparseRange::CLI::CLIError
  STDERR.puts "#{PROGRAM_NAME} [ERROR] #{e}"
  exit 1
end
