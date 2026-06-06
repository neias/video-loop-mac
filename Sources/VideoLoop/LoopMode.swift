import Foundation

/// Loop üretim yöntemi. Python aracındaki `--mode` ile birebir aynı.
enum LoopMode: String, CaseIterable, Identifiable, Sendable {
    case auto
    case crossfade
    case boomerang
    case swap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:      return "Auto"
        case .crossfade: return "Crossfade"
        case .boomerang: return "Boomerang"
        case .swap:      return "Swap"
        }
    }

    func summary(_ lang: AppLanguage) -> String {
        switch (self, lang) {
        case (.auto, .tr):
            return "Kareleri analiz edip en çok benzeyen başlangıç/bitiş çiftini bulur ve oradan keser. Görünmez sert kesim."
        case (.auto, .en):
            return "Analyzes frames, finds the most similar start/end pair and cuts there. Invisible hard cut."
        case (.crossfade, .tr):
            return "Videonun sonunu başına eritir (tek geçişli xfade)."
        case (.crossfade, .en):
            return "Dissolves the end of the video into its beginning (single-pass xfade)."
        case (.boomerang, .tr):
            return "İleri + geri (ping-pong). Her zaman %100 dikişsiz."
        case (.boomerang, .en):
            return "Forward + reverse (ping-pong). Always 100% seamless."
        case (.swap, .tr):
            return "Videoyu ortadan böler, parçaları yer değiştirir, ortada crossfade yapar."
        case (.swap, .en):
            return "Splits the video in the middle, swaps the halves and crossfades at the seam."
        }
    }

    var symbol: String {
        switch self {
        case .auto:      return "wand.and.stars"
        case .crossfade: return "circle.lefthalf.filled"
        case .boomerang: return "arrow.left.arrow.right"
        case .swap:      return "rectangle.2.swap"
        }
    }

    /// auto modunda geçiş varsayılanı 0 (sert görünmez kesim), diğerlerinde 1.0 sn.
    var defaultXfade: Double {
        self == .auto ? 0.0 : 1.0
    }

    /// xfade ayarı bu mod için anlamlı mı?
    var usesXfade: Bool {
        self != .boomerang
    }
}

/// Çıktı üretimi için tüm parametreler.
struct LoopOptions: Sendable {
    var mode: LoopMode = .auto
    var xfade: Double = 0.0
    var minLoop: Double = 2.0
    var crf: Int = 18
    var preset: String = "medium"
    var includeAudio: Bool = false

    static let presets = [
        "ultrafast", "superfast", "veryfast", "faster",
        "fast", "medium", "slow", "slower", "veryslow"
    ]
}

/// ffprobe çıktısından çıkarılan temel bilgiler.
struct VideoInfo: Sendable {
    var duration: Double
    var fps: Double
    var hasAudio: Bool
}
