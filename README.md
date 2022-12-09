# monitor

Quick HTTP Load utility

## Installation

1. [Install Crystal](https://crystal-lang.org/docs/installation/)
2. `git clone` this repo
3. `cd` into the repo
4. `shards build`

## Usage

The `monitor` application takes a few arguments:

1. `-u` or `--url` - The URL to test
2. `-c` or `--concurrency` - The number of concurrent requests to make (defualts to 10)
3. `-t` or `--total-requests` - The total number of requests to make (defaults to 1000)
4. `-a` or `--attack` - Adds a `<script>alert(1)</script>` to the end of the URL

`bin/monitor --url https://brightsec.com/`

```bash
WAFs detected: Armor Protection (Armor Defense), CloudFlare Web Application Firewall (CloudFlare)
┌───────────┬───────┬─────────────────────────────────────────────────────────────────────┐
│ Responses │ Count │ Description                                                         │
├───────────┼───────┼─────────────────────────────────────────────────────────────────────┤
│ 503       │ 3     │ Service Unavailable - This means something is wrong with the server │
│ 200       │ 24    │ OK                                                                  │
│ 429       │ 973   │ Too Many Requests - This means we are being rate limited            │
└───────────┴───────┴─────────────────────────────────────────────────────────────────────┘
Debug Files Created: 976
```

Debug files will be saved to the `/tmp/[hostname]` folder, and will be named as `[hostname].random_number.html`
those files can be easily opened with a browser to see the response.

## Contributing

1. Fork it (<https://github.com/NeuraLegion/monitor/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Bar Hofesh](https://github.com/bararchy) - creator and maintainer
