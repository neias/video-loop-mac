#!/bin/bash
# VideoLoop'u derleyip çift tıklanabilir bir VideoLoop.app paketi oluşturur.
set -e
cd "$(dirname "$0")"

echo "▶ Release derleniyor..."
swift build -c release

BIN=".build/release/VideoLoop"
APP="VideoLoop.app"

echo "▶ Uygulama paketi hazırlanıyor: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/VideoLoop"

# Uygulama ikonu (yoksa logo.png'den üret).
if [ ! -f AppIcon.icns ] && [ -f logo.png ]; then
    ./make-icon.sh
fi
if [ -f AppIcon.icns ]; then
    cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
# Uygulama içi başlıkta kullanmak üzere logoyu da pakete koy.
[ -f logo.png ] && cp logo.png "$APP/Contents/Resources/logo.png"

# Gömülü statik ffmpeg/ffprobe (varsa) → başka Mac'te bağımlılıksız çalışır.
# EMBED_FFMPEG=0 ile atlanır (örn. Homebrew cask'ı ffmpeg'i ayrı kurar).
if [ "${EMBED_FFMPEG:-1}" = "0" ]; then
    echo "  ffmpeg gömme atlandı (EMBED_FFMPEG=0) → sistemdeki ffmpeg kullanılır."
elif [ -f vendor/ffmpeg ] && [ -f vendor/ffprobe ]; then
    mkdir -p "$APP/Contents/Resources/bin"
    cp vendor/ffmpeg vendor/ffprobe "$APP/Contents/Resources/bin/"
    chmod +x "$APP/Contents/Resources/bin/ffmpeg" "$APP/Contents/Resources/bin/ffprobe"
    echo "  gömülü: ffmpeg + ffprobe (universal statik)"
else
    echo "  not: vendor/ffmpeg yok → uygulama sistemdeki ffmpeg'e bağımlı kalır."
    echo "       Gömmek için önce ./fetch-ffmpeg.sh çalıştır."
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>VideoLoop</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.emreacar.videoloop</string>
    <key>CFBundleName</key>
    <string>VideoLoop</string>
    <key>CFBundleDisplayName</key>
    <string>VideoLoop</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc imza: önce gömülü ikililer (içeriden dışarıya), sonra uygulama.
for b in "$APP/Contents/Resources/bin/ffmpeg" "$APP/Contents/Resources/bin/ffprobe"; do
    [ -f "$b" ] && codesign --force --sign - --timestamp=none "$b" 2>/dev/null || true
done
codesign --force --sign - --timestamp=none "$APP" 2>/dev/null || true

echo "✓ Bitti: $(pwd)/$APP"
echo "  Açmak için:  open \"$APP\"   (veya Finder'dan çift tıkla)"
