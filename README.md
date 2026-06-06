# VideoLoop (SwiftUI)

A native macOS SwiftUI app — the GUI port of the `videoloop.py` tool — that turns
a video into a seamless loop. It drives **ffmpeg / ffprobe** under the hood.

## Modes

| Mode | Description |
|------|-------------|
| **Auto** | Analyzes frames (32×18 grayscale), finds the most similar start/end pair and cuts there. Invisible hard cut. |
| **Crossfade** | Dissolves the end of the video into its beginning (single-pass `xfade` + `acrossfade`). |
| **Boomerang** | Forward + reverse (ping-pong). Always 100% seamless. |
| **Swap** | Splits the video in the middle, swaps the halves, and crossfades at the seam. |

## Install (Homebrew)

```bash
brew install --cask neias/tap/videoloop
```

If this is your first time using a third-party tap, Homebrew may ask you to trust it:

```bash
brew tap neias/tap
brew trust neias/tap          # or: export HOMEBREW_NO_REQUIRE_TAP_TRUST=1
brew install --cask videoloop
```

The `ffmpeg` dependency is installed automatically. The app is ad-hoc signed
(not notarized), so the cask removes the quarantine flag after install.

Uninstall: `brew uninstall --cask videoloop`

## Requirements

None for the Homebrew install — `ffmpeg` is pulled in as a dependency.

For a **standalone** build, ffmpeg/ffprobe can be embedded inside the app bundle
(universal static: arm64 + x86_64), so it runs on any Mac with no install. During
development, if no embedded binary is present it falls back to the system
`brew install ffmpeg`.

## Build & Run

```bash
./fetch-ffmpeg.sh   # download static ffmpeg/ffprobe + make universal (once, optional)
./build.sh          # produce VideoLoop.app (embeds the binaries if vendor/ exists)
open VideoLoop.app  # or double-click in Finder
```

Build a lean app that relies on system/Homebrew ffmpeg instead of embedding:

```bash
EMBED_FFMPEG=0 ./build.sh
```

During development you can also run directly:

```bash
swift run
```

## Distributing to another Mac (standalone)

Zip the app and send it:

```bash
ditto -c -k --keepParent VideoLoop.app VideoLoop.zip
```

Because the app is **ad-hoc** signed (not notarized by an Apple Developer
account), Gatekeeper will warn on first launch on the other Mac. On the
recipient's side:

- **Right-click → Open** → "Open" (once), or
- Remove the quarantine flag: `xattr -dr com.apple.quarantine VideoLoop.app`

> A standalone app is ~253 MB (two universal binaries). If you only target Apple
> Silicon, thin the `vendor/` binaries with `lipo -thin arm64` to roughly halve it.

## Usage

1. **Drag & drop** a video onto the window, or click to choose one.
2. Pick a mode and settings (xfade, min loop, CRF, preset, audio).
3. **Create Loop** → choose the output location → watch the progress bar.
4. When done, **Watch** the result (looping preview) or reveal it in Finder.

## Settings

- **xfade** — transition duration (s). For Auto, 0 = hard invisible cut.
- **Min loop** — minimum loop length in Auto mode.
- **CRF** — x264 quality (lower = better, default 18).
- **Preset** — x264 speed/compression trade-off.
- **Keep audio** — when off, audio is dropped. Auto mode always drops audio.

## Architecture

| File | Responsibility |
|------|----------------|
| `LoopMode.swift` | Mode / options / `VideoInfo` models |
| `FFmpegTools.swift` | Locating ffmpeg-ffprobe, running processes, progress parsing |
| `Looper.swift` | `probe`, frame-similarity analysis, the four mode builders |
| `LoopEngine.swift` | UI ↔ worker bridge (`ObservableObject`) |
| `ContentView.swift` | SwiftUI interface |
| `LoopPlayerView.swift` | Looping AVKit preview of the result |
| `VideoLoopApp.swift` | App entry point |
