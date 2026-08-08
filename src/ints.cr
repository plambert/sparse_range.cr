# Entry point for the `ints` executable. The implementation lives in
# `SparseRange::CLI`; this file only wires it to the process.

require "./cli"

begin
  SparseRange::CLI.new.run
rescue error : SparseRange::CLI::CLIError | ArgumentError | OverflowError
  STDERR.puts "#{PROGRAM} [ERROR] #{error.message} (try --help)"
  exit 1
rescue error : IO::Error
  # A closed pipe (`ints ... | head`) is a normal way for this program to end.
  raise error unless error.os_error == Errno::EPIPE
  exit 0
end
