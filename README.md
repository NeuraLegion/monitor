# monitor

Quick HTTP Load utility

## Installation

1. [Install Crystal](https://crystal-lang.org/docs/installation/)
2. `git clone` this repo
3. `cd` into the repo
4. `shards build`

## Usage

`bin/monitor --url https://brightsec.com/`
Output:

```bash
┌──────────────────┬───────┬─────────────────────────────────────────────────────────────┐
│ Responses        │ Count │ Description                                                 │
├──────────────────┼───────┼─────────────────────────────────────────────────────────────┤
│ IO::TimeoutError │ 407   │ connect timed out                                           │
│ 502              │ 431   │ Bad Gateway - This means something is wrong with the server │
│ 200              │ 162   │ OK                                                          │
└──────────────────┴───────┴─────────────────────────────────────────────────────────────┘
```

## Contributing

1. Fork it (<https://github.com/NeuraLegion/monitor/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Bar Hofesh](https://github.com/bararchy) - creator and maintainer
