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

    var summary: String {
        switch self {
        case .auto:
            return "Kareleri analiz edip en çok benzeyen başlangıç/bitiş çiftini bulur ve oradan keser. Görünmez sert kesim."
        case .crossfade:
            return "Videonun sonunu başına eritir (tek geçişli xfade)."
        case .boomerang:
            return "İleri + geri (ping-pong). Her zaman %100 dikişsiz."
        case .swap:
            return "Videoyu ortadan böler, parçaları yer değiştirir, ortada crossfade yapar."
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
