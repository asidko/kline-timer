# Kline Timer

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange?logo=swift&logoColor=white)](https://swift.org)
[![Platform](https://img.shields.io/badge/macOS-13+-black?logo=apple)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/asidko/kline-timer/actions/workflows/ci.yml/badge.svg)](https://github.com/asidko/kline-timer/actions/workflows/ci.yml)

A light, native macOS menu-bar app that counts down the current trading candle and
restarts itself for the next one. Under a minute it turns red and shows the seconds.

No Dock icon, no window — it lives in the menu bar. Pure Swift on AppKit + SwiftUI,
zero third-party dependencies.

![Kline Timer demo](docs/demo.gif)

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/asidko/kline-timer/main/install.sh | sh
```

Pin a version with `… | sh -s -- --tag v1.0.0`, or uninstall with `… | sh -s -- --remove`.
Or download `KlineTimer.dmg` from [Releases](https://github.com/asidko/kline-timer/releases),
open it, and drag **Kline Timer** onto **Applications**.

Then click the candle icon in the menu bar, pick a timeframe, and trade your candle.

## Why

Scalpers and intraday traders live and die by the candle close — entries, exits, and
confirmation all hinge on *when this bar ends*. Reading that off a chart means keeping a
chart tab open and doing mental math against the wall clock. Kline Timer collapses that
to one glance at the menu bar: the exact seconds to close, on the timeframe you're trading.

## How it compares

- **A chart tab left open** — works, but it's a whole window and you still eyeball the close. Kline Timer is a glanceable line in the menu bar.
- **A generic countdown / Pomodoro timer** — counts down a fixed duration you set by hand. Kline Timer aligns to real exchange candle boundaries and auto-restarts every close, so you never reset it.

## Usage

Click the menu-bar item to open the panel: a live readout, the timeframe picker
(1m, 3m, 5m, 15m, 30m, 1h, 2h, 4h), two toggles, and Quit (⌘Q).

The menu-bar item has three states:

- **Ticking, time shown** — glyph plus timeframe and remaining, e.g. `5m · 3:24`. Default.
- **Ticking, time hidden** — just the glyph. Turn off *Show countdown in menu bar*.
- **Final minute** — red glyph and seconds (`0:47`), pulsing, shown even when the countdown is otherwise hidden. Restarts automatically at zero.

## Configuration

There's no config file — preferences are set in the panel and persisted via macOS
`UserDefaults` (`com.kline.timer`):

- **Timeframe** — the candle interval to count down.
- **Show countdown in menu bar** — off leaves just the icon.
- **Voice / chime on close** — a short system beep when a candle closes.

Candle boundaries align to UTC, exactly like exchange klines: 5m candles close at
:00/:05/:10, 4h candles at 00:00/04:00/08:00 UTC. The countdown is recomputed from the
wall clock every second, so it never drifts.

## Build from source

Requires Swift 5.9+ (Xcode or the Command Line Tools).

```sh
swift run            # build and launch the menu-bar app
swift test           # run the countdown unit tests
./bundle.sh          # build KlineTimer.app, then: open KlineTimer.app
```

### Architecture

Two targets enforce the layering:

- `Sources/KlineCore` — pure countdown domain: `Timeframe` and `CandleClock`
  (epoch-aligned remaining-seconds math and formatting). No AppKit, fully unit-tested.
- `Sources/KlineTimer` — the app: `StatusItemController` (menu bar), `PopoverView`
  (SwiftUI panel), `Settings`/`TimerModel` (state), `Chime`, wired by `AppDelegate`.

The UI never does candle math; the core never imports AppKit. The one-second clock
lives in `AppDelegate` and pushes computed values out to both the status item and the panel.

## License

[MIT](LICENSE) © Alexander Sidko
