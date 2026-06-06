#!/bin/bash
# logo.png'den macOS uygulama ikonu (AppIcon.icns) üretir.
# Logo şeffaf zemine, kenarlarda biraz boşluk bırakacak şekilde yerleştirilir.
set -e
cd "$(dirname "$0")"

SRC="logo.png"
[ -f "$SRC" ] || { echo "logo.png yok"; exit 1; }

WORK="$(mktemp -d)"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

# Logoyu, kenarda boşluk olan şeffaf 1024'lük tuvale en-boy oranını koruyarak
# ortala (master). Compositing için küçük bir Swift betiği kullanılır.
MASTER="$WORK/master.png"
cat > "$WORK/pad.swift" <<'SWIFT'
import AppKit
let src = CommandLine.arguments[1]
let out = CommandLine.arguments[2]
let canvas: CGFloat = 1024
let pad: CGFloat = 150          // her kenarda boşluk
let inner = canvas - 2 * pad
guard let img = NSImage(contentsOfFile: src) else { exit(1) }
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let s = img.size
let scale = min(inner / s.width, inner / s.height)
let w = s.width * scale, h = s.height * scale
let x = (canvas - w) / 2, y = (canvas - h) / 2
img.draw(in: NSRect(x: x, y: y, width: w, height: h), from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: out))
print("master 1024x1024 yazildi")
SWIFT
swift "$WORK/pad.swift" "$SRC" "$MASTER"

# iconset boyutları.
gen() { sips -z "$2" "$2" "$MASTER" --out "$ICONSET/$1" >/dev/null; }
gen icon_16x16.png        16
gen icon_16x16@2x.png     32
gen icon_32x32.png        32
gen icon_32x32@2x.png     64
gen icon_128x128.png      128
gen icon_128x128@2x.png   256
gen icon_256x256.png      256
gen icon_256x256@2x.png   512
gen icon_512x512.png      512
gen icon_512x512@2x.png   1024

iconutil -c icns "$ICONSET" -o AppIcon.icns
rm -rf "$WORK"
echo "✓ AppIcon.icns üretildi."
