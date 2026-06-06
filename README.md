# VideoLoop (SwiftUI)

`videoloop.py` aracının yerel macOS SwiftUI uygulaması. Bir videoyu kusursuz
(seamless) döngüye çevirir. Arka planda sistemdeki **ffmpeg / ffprobe** kullanılır.

## Modlar

| Mod | Açıklama |
|-----|----------|
| **Auto** | Kareleri (32×18 gri) analiz edip en çok benzeyen başlangıç/bitiş çiftini bulur ve oradan keser. Görünmez sert kesim. |
| **Crossfade** | Videonun sonunu başına eritir (tek geçişli `xfade` + `acrossfade`). |
| **Boomerang** | İleri + geri (ping-pong). Her zaman %100 dikişsiz. |
| **Swap** | Videoyu ortadan böler, parçaları yer değiştirir, ortada crossfade yapar. |

## Gereksinim

Yok — **ffmpeg/ffprobe uygulamanın içine gömülüdür** (universal statik: arm64 + x86_64).
Başka bir Mac'te kurulum gerektirmeden çalışır. (Geliştirme sırasında gömülü
ikili yoksa sistemdeki `brew install ffmpeg`'e düşer.)

## Derleme & Çalıştırma

```bash
./fetch-ffmpeg.sh   # statik ffmpeg/ffprobe indir + universal yap (bir kez)
./build.sh          # VideoLoop.app paketini üretir (ikilileri gömer)
open VideoLoop.app  # ya da Finder'dan çift tıkla
```

`vendor/ffmpeg` zaten varsa `fetch-ffmpeg.sh`'ı atlayabilirsin.

## Başka bir Mac'e dağıtım

`VideoLoop.app`'i sıkıştırıp gönder:

```bash
ditto -c -k --keepParent VideoLoop.app VideoLoop.zip
```

Uygulama **ad-hoc** imzalı (Apple Developer ile notarize edilmemiş) olduğundan,
karşı Mac'te ilk açılışta Gatekeeper uyarı verir. Çözüm (alıcı tarafında):

- **Sağ tık → Aç** → "Aç" (bir kez), ya da
- Terminalde karantinayı kaldır: `xattr -dr com.apple.quarantine VideoLoop.app`

> Boyut ~253 MB (iki universal ikili). Sadece Apple Silicon hedefliyorsan
> `vendor/` içindekileri `lipo -thin arm64` ile inceltip yarıya düşürebilirsin.

Geliştirme sırasında doğrudan:

```bash
swift run
```

## Kullanım

1. Videoyu pencereye **sürükle-bırak** ya da tıklayıp seç.
2. Yöntemi ve ayarları (xfade, en kısa loop, CRF, preset, ses) belirle.
3. **Loop Oluştur** → çıktı konumunu seç → ilerleme çubuğunu izle.
4. Bittiğinde **Finder'da Göster** / **Aç**.

## Ayarlar

- **xfade** — geçiş süresi (sn). Auto için 0 = sert görünmez kesim.
- **En kısa loop** — auto modunda minimum döngü uzunluğu.
- **CRF** — x264 kalite (düşük = daha iyi, varsayılan 18).
- **Preset** — x264 hız/sıkıştırma dengesi.
- **Sesi koru** — kapalıysa ses atılır. Auto modunda ses her zaman atılır.

## Mimari

| Dosya | Sorumluluk |
|-------|-----------|
| `LoopMode.swift` | Mod/parametre/`VideoInfo` modelleri |
| `FFmpegTools.swift` | ffmpeg-ffprobe konum bulma, process çalıştırma, ilerleme parse |
| `Looper.swift` | `probe`, kare-benzerliği analizi, dört mod kurucu |
| `LoopEngine.swift` | UI ↔ worker köprüsü (`ObservableObject`) |
| `ContentView.swift` | SwiftUI arayüz |
| `VideoLoopApp.swift` | Uygulama girişi |
