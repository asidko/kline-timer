import AppKit

// `KlineTimer --version` / `--help` from a terminal; anything else (including the
// arguments Finder/launchd pass) starts the menu-bar agent.
switch CommandLine.arguments.dropFirst().first {
case "--version":
    print("Kline Timer \(AppVersion.value)")
    exit(0)
case "--help", "-h":
    print("""
    Kline Timer \(AppVersion.value) — menu-bar candle-close countdown for traders.

    Run with no arguments to launch in the menu bar.

    Options:
      --version   print the version and exit
      --help      print this help and exit
    """)
    exit(0)
default:
    break
}

// Menu-bar agent: no Dock icon, no app menu bar — lives entirely in the status bar.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
