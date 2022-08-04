# SparseRange

Manage a set of ranges of Int32 or Float64.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     sparse_range:
       github: your-github-user/sparse_range
   ```

2. Run `shards install`

## Usage

```crystal
require "sparse_range"
```

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/your-github-user/sparse_range/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Paul M. Lambert](https://github.com/plambert) - creator and maintainer


Test: r.begin >= range_to_add_begin.pred
Test: r.begin >= range_to_add_end.succ

Given: [10..12, 20..22, 30..32]

Add: [ 0..2 ] insert before 0 (10..12)
              [0..2, 10..12, 20..22, 30..32]
              0,0

Add: [ 0..11] merge into 0 (10..12)
              [0..12, 20..22, 30..32]
              0,1

Add: [ 0..19] merge into 0,1 (10..12, 20..22)
              [0..22, 30..32]
              0,1

Add: [10..15] merge into 0 (10..12)
              [10..15, 20..22, 30..32]
              0,1

Add: [15..17] insert before 1 (20..22)
              [10..12, 15..17, 20..22, 30..32]
              1,1

Add: [15..19] merge into 1 (20..22)
              [10..12, 15..22, 30..32]
              1,

Add: [21..25] merge into 1 (20..22)
              [10..12, 20..25, 30..32]

Add: [11..31] merge into 0,1,2 (10..12, 20..25, 30..32)
              [10..32]

Add: [25..29] merge into 2 (30..32)
              [10..12, 20..22, 25..32]

Add: [25..31] merge into 2 (30..32)
              [10..12, 20..22, 25..32]

Add: [30..35] merge into 2 (30..32)
              [10..12, 20..22, 30..35]

Add: [33..33] merge into 2 (30..32)
              [10..12, 20..22, 30..33]

Add: [35..39] append after 2 (30..32)
              [10..12, 20..22, 30..32, 35..39]
