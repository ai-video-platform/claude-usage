# Claude Usage

A free, private, open source app that shows your Claude usage limits at a glance: in the macOS menu bar, on your Mac desktop, and on your iPhone and iPad Home Screen and Lock Screen.

It mirrors what you see on claude.ai, the rolling 5 hour session limit, the weekly limits (all models plus the per model sub limits), reset times, and any extra usage credits, in a calm, glanceable design.

## Features

- Live 5 hour and weekly usage, each with a pace marker that shows how far through the window you are.
- A plain language read of where you stand and which limit you will hit first.
- A weekly per model breakdown, taken from your account's real data (no fixed model list, so new models appear automatically).
- Extra usage credits: remaining balance and monthly spend.
- History: usage trends over time and a year activity grid, built and stored on device.
- Alerts: a flexible notification rules system (cross a threshold, on pace to hit a limit, before a reset, and more).
- Widgets: small, medium, and large, plus iOS Lock Screen and StandBy.
- macOS: a menu bar item with selectable styles and a native window.
- macOS extra: optional Claude Code stats from your local logs (opt in, read only, on device).

## Privacy

- You sign in on Claude's own web page. The app never sees your password.
- Your session is stored only in this device's Keychain.
- There are no servers and no accounts. Nothing leaves your device.

## Requirements

- macOS 14 or later, or iOS / iPadOS 17 or later. Liquid Glass on macOS 26 and iOS 26, with a material fallback below that.
- A Claude Pro or Max plan. Team, Enterprise, and Google sign in are not supported.

## Build

Open `Claude Usage.xcodeproj` in Xcode and run the `Claude Usage` scheme. The shared engine is a local Swift package in `Core`, with its own tests:

```
cd Core && swift test
```

## Disclaimer

This is an independent app. It is not affiliated with, endorsed by, or sponsored by Anthropic. "Claude" is a trademark of Anthropic, used here only to describe what the app reads.

## License

MIT. See [LICENSE](LICENSE).
