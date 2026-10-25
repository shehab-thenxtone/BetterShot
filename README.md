# BetterShot

macOS menu-bar screenshot and screen-recording utility: capture, annotate, copy/save/pin/share.

- Requirements: [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)
- Architecture & plan: [docs/PLAN.md](docs/PLAN.md)

## Develop

Requires macOS 14+ and Xcode 16+ (Swift 6).

```sh
swift build          # build all modules
swift test           # run unit tests
scripts/bundle.sh    # produce build/BetterShot.app (menu-bar agent)
open build/BetterShot.app
```
