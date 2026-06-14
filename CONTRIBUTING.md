# Contributing

Thanks for your interest in improving Claude Usage.

## Getting started

Open `Claude Usage.xcodeproj` in Xcode and run the `Claude Usage` scheme. The shared engine is a Swift package in `Core`, with its own tests:

```
cd Core && swift test
```

## Guidelines

- Keep everything on device. The app has no servers and no analytics. Please keep it that way.
- Prefer native SwiftUI and system components, and match the existing style.
- For user facing text, lead with meaning and keep it calm and clear.

## Issues and pull requests

Use the issue templates for bugs and feature requests. For bugs, include your device, OS, and Claude plan.

By contributing, you agree that your contributions are licensed under the MIT license.
