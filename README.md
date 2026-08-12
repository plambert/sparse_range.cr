# SparseRange

[![docs](https://img.shields.io/badge/docs-latest-blue)](https://plambert.github.io/sparse_range.cr/latest/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

A Crystal shard for managing a sorted, coalesced set of integer ranges — the kind of thing
you would write on a command line as `1..10,30,99..101`.

A `SparseRange(T)` keeps its ranges sorted by `begin`, non-overlapping, and non-adjacent.
Adding `4` to `[1..3, 5..10]` yields `[1..10]`, not three ranges.

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  sparse_range:
    github: plambert/sparse_range.cr
```

The dependency key must be `sparse_range`, to match the `name:` in this shard's `shard.yml`;
the `github:` value must be `plambert/sparse_range.cr`, the actual repository name, including
the `.cr` suffix.

Then run `shards install`.

There are no published tags yet, so `shards` resolves the default branch. Pin with `branch:`
or `commit:` if you need reproducibility.

## Usage

### Building a set

```crystal
require "sparse_range"

sparserange = SparseRange(Int32).new
sparserange.add 21
sparserange.add 1234..1243

sparserange.ranges # => [21..21, 1234..1243]
sparserange.size   # => 2      number of distinct ranges
sparserange.count  # => 11     number of integers contained
sparserange.span   # => 1223   max - min + 1
```

Overlapping and adjacent input is coalesced automatically:

```crystal
sparserange = SparseRange(Int32).new([1..3, 5..10])
sparserange.add 4
sparserange.ranges # => [1..10]
sparserange.size   # => 1
```

### Parsing a list

```crystal
sparserange = SparseRange(Int32).new(list: "1..10,30,99..101")
sparserange.ranges # => [1..10, 30..30, 99..101]
sparserange.min    # => 1
sparserange.max    # => 101
sparserange.count  # => 14
```

The parser accepts bare integers, inclusive ranges (`a..b`), exclusive ranges (`a...b`), and
an optional surrounding `[` `]`. Anything else raises `SparseRange::ParseException`, as does a
value too large for `T`.

### Adding and subtracting

```crystal
sparserange = SparseRange(Int32).new
sparserange.add 1..10, 20..30
sparserange.subtract 5..6
sparserange.ranges # => [1..4, 7..10, 20..30]

(sparserange - (25..40)).ranges # => [1..4, 7..10, 20..24]
(sparserange + 100).ranges      # => [1..4, 7..10, 20..30, 100..100]
```

`#add` and `#subtract` mutate the receiver and return `self`. `#+` and `#-` work on a copy and
leave the receiver alone. `#<<` is an alias for `#add`:

```crystal
sparserange = SparseRange(Int32).new
sparserange << 5 << (7..9)
sparserange.ranges # => [5..5, 7..9]
```

Exclusive ranges are normalised to inclusive ones and empty ranges are ignored, so
`add(5...10)` stores `5..9` and `add(5...5)` stores nothing. A reversed range such as `10..5`
raises `ArgumentError` rather than corrupting the set.

### Iterating

```crystal
sparserange = SparseRange(Int32).new([1..3, 7..8])

sparserange.each.to_a       # => [1, 2, 3, 7, 8]
sparserange.each_range.to_a # => [1..3, 7..8]

sparserange.each_excluded { |value| print value } # prints 456
```

`#each` and `#each_range` return an `Iterator` when called without a block and yield when
called with one. `#each_excluded` walks the gaps, by default between `#min` and `#max`, or
between an explicit `start_at` and `end_at`:

```crystal
sparserange = SparseRange(Int32).new(list: "10..12,20..22")
sparserange.each_excluded(0, 15) { |value| print value, ' ' }
# prints: 0 1 2 3 4 5 6 7 8 9 13 14 15
```

### Inverting

`#invert` returns the complement over the full domain of `T`, and `#invert!` does it in place:

```crystal
sparserange = SparseRange(Int8).new([0_i8..3_i8])
sparserange.invert.ranges # => [-128..-1, 4..127]
```

### Bit vectors

```crystal
SparseRange(Int32).new(list: "1,3,5").to_bitstring # => "010101"
SparseRange(Int32).new(list: "1,3,5").to_bitarray  # => BitArray[010101]
```

Both count from zero, so they raise `ArgumentError` for a set containing negative values, or
one whose maximum is too large to index a `BitArray`.

### JSON

```crystal
sparserange = SparseRange(Int32).new(list: "1..3,10")
text = sparserange.to_json                # => "[[1,3],[10,10]]"
SparseRange(Int32).from_json(text).ranges # => [1..3, 10..10]
```

The wire format is an array of `[begin, end]` pairs. Pairs need not be sorted on the way in,
but each must be non-decreasing.

### Counting

`#count` and `#span` return `UInt128`, so they stay correct across the full width of `T`:

```crystal
SparseRange(Int32).new([Int32::MIN..Int32::MAX]).count # => 4294967296
```

`#count` is memoized and recomputed only after the set changes.

## Range extensions

Requiring this shard reopens the stdlib `Range` struct **process-wide**. This is a global side
effect on every `Range` in your program, not just the ones inside a `SparseRange`. It adds
`#no_values?`, `#overlaps?`, `#abuts?`, `#overlaps_or_abuts?`, `#merge`, `#merge?`, `#merge!`
and `#<=>`:

```crystal
(1..5).overlaps? 4..8 # => true
(1..5).abuts? 6..8    # => true
(1..5).merge 4..8     # => 1..8
(1..5).merge? 10..12  # => nil
(10..5).no_values?    # => true
```

Nothing here overrides an existing stdlib method, and `Range` is deliberately **not** made
`Comparable`: `#<=>` is a plain method, so `<`, `>`, `<=`, `>=` and `#clamp` keep their stdlib
behaviour, which is to stay undefined. Sort explicitly if you want this ordering:

```crystal
[5..6, 1..2, 3..4].sort { |a, b| a <=> b } # => [1..2, 3..4, 5..6]
```

`#overlaps?` and `#abuts?` raise `ArgumentError` on exclusive ranges; normalise `a...b` to
`a..b.pred` first.

## Supported integer types

The generic class works with any `T` responding to `#succ`, `#pred`, `::MIN` and `::MAX`,
which in practice means every integer type. `SparseRange.new(Int32)` and friends are
convenience constructors generated for `Int8`, `UInt8`, `Int16`, `UInt16`, `Int32`, `UInt32`,
`Int64`, `UInt64`, `Int128` and `UInt128`, forwarding both positional and named arguments:

```crystal
SparseRange.new(UInt32).ranges                 # => []
SparseRange.new(Int32, [1..5]).ranges          # => [1..5]
SparseRange.new(Int64, list: "1..10,30").ranges # => [1..10, 30..30]
```

The class argument decides the element type, so `SparseRange(Int64).new(Int32)` returns a
`SparseRange(Int32)`.

`#to_i16?`, `#to_u16?`, `#to_i32?`, … `#to_u128?` convert between widths, returning `nil` if
any value would not fit:

```crystal
SparseRange(Int32).new(list: "1..3").to_u16?  # => SparseRange(UInt16)[1..3]
SparseRange(Int32).new(list: "-5..-1").to_u32? # => nil
```

8-bit conversions are intentionally omitted: at that width a `BitArray` is both denser and
faster than a list of ranges.

## The `ints` CLI

The shard ships a command-line front end that builds a `SparseRange(Int64)` from its
arguments and prints it. Build it with `shards build ints`; the binary lands in `bin/ints`.

```console
$ bin/ints 1 2 3 5..10
1..3,5..10

$ bin/ints --each 1 2 3 5..10
1,2,3,5,6,7,8,9,10

$ bin/ints 5-10 12
5..10,12

$ bin/ints 1...5
1..4

$ bin/ints --json 1..3 5
[[1,3],[5,5]]

$ bin/ints --json --each 1..3 5
[1,2,3,5]

$ bin/ints --bits 0 5
100001

$ bin/ints --lines 1..3 5..7
1..3
5..7

$ bin/ints --curly-brackets 1..3 5
{1..3,5}
```

Arguments may be single integers (`5`, `-3`), inclusive ranges (`5-10` or `5..10`), or
exclusive ranges (`5...10`). Use `--` to stop option parsing. Run `bin/ints --help` for the
full option list, covering output format (`--list`, `--json`, `--bits`), layout (`--compact`,
`--each`, `--lines`, `--delimiter`) and brackets.

`--json` always emits valid JSON and ignores the delimiter and bracket options. `--bits`
counts from zero, so it rejects sets containing negative values. Bad input produces a message
on stderr and a non-zero exit, never a stack trace, and a closed pipe exits cleanly.

## Development

```bash
shards install                 # fetch dependencies (Spectator, for the specs)
crystal spec                   # run the test suite
crystal spec -- --order rand   # run it in a randomised order
crystal spec -v --error-trace  # verbose, with full backtraces
crystal tool format            # format all .cr files
ameba                          # lint (configured in .ameba.yml)
shards build ints              # build the CLI into bin/ints
crystal docs                   # generate API docs into docs/
```

`ameba` is not a declared dependency; install it separately (`brew install ameba`, or
`nix profile install nixpkgs#ameba`).

Set `SPARSE_RANGE_DEBUG=1`, or pass `debug: true` to a constructor, to trace `#add`,
`#subtract` and `#sort!` on stderr.

Specs use [Spectator](https://gitlab.com/arctic-fox/spectator). `spec/per_type_spec.cr`
generates one behavioural suite for all ten integer types, including their `T::MIN` and
`T::MAX` boundaries; `spec/regression_spec.cr` holds the cross-cutting invariant and property
tests, including a randomised differential test against `Set(Int32)`. Add new behavioural
tests to one of those two rather than to a single type.

## Contributing

1. Fork it (<https://github.com/plambert/sparse_range.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

Run `crystal tool format`, `crystal spec` and `ameba` before opening a pull request.

## Contributors

* [Paul M. Lambert](https://github.com/plambert) — creator and maintainer

## License

MIT — see [LICENSE](./LICENSE).
