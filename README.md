# Claude Usage

A free, informational app that mirrors Claude's `/usage` (the 5 hour and weekly limits,
reset times, Opus vs Sonnet split, cost, and extra-credit balance) and surfaces it where you
glance: the Mac menu bar, Mac/iPhone/iPad widgets, the iOS Lock Screen, and StandBy.

No accounts, no servers, no in app purchases. Data stays on device and in your own iCloud.

## How it gets data

| Source | Gives us | When |
| --- | --- | --- |
| Local JSONL (`~/.claude/projects/**/*.jsonl`) | tokens, cost (computed), per model / per project, history | macOS, always; incremental mtime cache so refreshes are fast |
| OAuth-headers path (Claude Code token from the Keychain) | live 5 hour and weekly % + reset times | default live source, low privilege |
| claude.ai web session (optional "Connect claude.ai") | Opus vs Sonnet split + extra-credit balance + spend | when the user connects (sessionKey cookie, Keychain, device-only) |
| iCloud key-value store | the Mac's snapshot, mirrored to iPhone/iPad | iOS reads it (those devices can't see `~/.claude`) |

Live values are wrapped in a graceful-degrade cache: a failed fetch falls back to the last
good values (age-gated, reset-passed windows dropped) rather than going blank or showing 0%.
The extra-credit dollar balance has no official API; it comes only from the claude.ai path.

## Architecture

```
  macOS app (unsandboxed, reads ~/.claude + Keychain)
    Core engine: incremental JSONL parse -> cost/burn/forecast
    + live limits (OAuth headers, or claude.ai cookie)
    -> UsageSnapshot
         |--> App Group container  -> WidgetKit widgets (mac/iOS/iPad, incl. Lock Screen / StandBy)
         |--> iCloud KVS           -> iPhone / iPad app
         +--> local notifications (threshold alerts + reset "you're back" ping)
```

The engine lives in a SwiftPM package (`Core`, product `HeadroomCore`) shared by the app, the
widget extension, and a dev CLI (`headroom`). The app is `Claude Usage` (SwiftUI, multiplatform).

## Deployment targets

iOS 17 / iPadOS 17 / macOS 14 Sonoma. (A watchOS target with complications is not built yet.)

## Distribution

macOS is unsandboxed (it must read `~/.claude` and the Keychain) with hardened runtime on, so
the channel is Developer ID / notarized, not the Mac App Store. App Group + iCloud capabilities
must be enabled once in Xcode for signed builds (entitlements + `REGISTER_APP_GROUPS` are set).

## Status

- [x] Core engine: JSONL parse (dedup, synthetic-model exclusion), pricing, aggregation, snapshot, incremental scan cache
- [x] Live limits: OAuth-headers path (verified), claude.ai web path (Opus/Sonnet + credits), graceful-degrade cache
- [x] macOS menu bar app + popover + Settings
- [x] WidgetKit widgets: system small/medium (mac + iOS), iOS accessory (Lock Screen / StandBy)
- [x] Notifications: configurable threshold alerts + reset ping
- [x] Sharing: App Group (widgets) + iCloud KVS (iPhone/iPad)
- [x] Tests: 16 Core unit tests
- [ ] App icon assets
- [ ] watchOS app + complications
- [ ] App-layer tests (UsageModel / NotificationManager)

## Run the dev CLI

```sh
cd Core
swift test
swift run -c release headroom            # full report from ~/.claude (cached after first run)
swift run headroom snapshot              # emit the UsageSnapshot JSON
swift run headroom live                  # prove the live OAuth limits path on this machine
```
