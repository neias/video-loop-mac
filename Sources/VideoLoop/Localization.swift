import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case tr

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .tr: return "Türkçe"
        }
    }

    var shortLabel: String {
        switch self {
        case .en: return "EN"
        case .tr: return "TR"
        }
    }
}

/// Uygulama dilini tutar ve çalışma anında değiştirilebilir kılar.
/// Seçim UserDefaults'a yazılır; ilk açılışta sistem diline göre belirlenir.
@MainActor
final class Localization: ObservableObject {
    private static let defaultsKey = "appLanguage"

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey) }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let lang = AppLanguage(rawValue: saved) {
            language = lang
        } else {
            let pref = Locale.preferredLanguages.first ?? "en"
            language = pref.hasPrefix("tr") ? .tr : .en
        }
    }

    var s: Strings { language == .tr ? .tr : .en }
}

/// Tüm görünür arayüz metinleri.
struct Strings {
    let subtitle: String
    let dropTitle: String
    let dropSubtitle: String
    let change: String
    let sectionMethod: String
    let sectionSettings: String
    let xfadeAuto: String
    let xfadeOther: String
    let xfadeHint: String
    let minLoop: String
    let quality: String
    let qualityHint: String
    let preset: String
    let keepAudio: String
    let keepAudioAuto: String
    let keepAudioOther: String
    let ffmpegMissing: String
    let ffmpegInstall: String
    let readyPrefix: String
    let watch: String
    let revealFinder: String
    let open: String
    let openDefault: String
    let log: String
    let createLoop: String
    let creating: String
    let secondsUnit: String
    let loopingBadge: String
    let close: String
    let chooseVideoTitle: String

    /// "%.1f <unit>" biçimi için.
    func secondsFormat() -> String { "%.1f \(secondsUnit)" }
}

extension Strings {
    static let en = Strings(
        subtitle: "Make a video loop seamlessly",
        dropTitle: "Drag a video here",
        dropSubtitle: "or click to choose",
        change: "Change",
        sectionMethod: "METHOD",
        sectionSettings: "SETTINGS",
        xfadeAuto: "Transition (xfade)",
        xfadeOther: "Transition duration (xfade)",
        xfadeHint: "0 = hard invisible cut",
        minLoop: "Min loop",
        quality: "Quality (CRF)",
        qualityHint: "lower = better",
        preset: "Preset",
        keepAudio: "Keep audio",
        keepAudioAuto: "audio is always dropped in auto mode",
        keepAudioOther: "audio is dropped when off",
        ffmpegMissing: "ffmpeg not found",
        ffmpegInstall: "Install in Terminal:  brew install ffmpeg",
        readyPrefix: "Ready",
        watch: "Watch",
        revealFinder: "Reveal in Finder",
        open: "Open",
        openDefault: "Open in Default Player",
        log: "Log",
        createLoop: "Create Loop",
        creating: "Creating…",
        secondsUnit: "s",
        loopingBadge: "looping",
        close: "Close",
        chooseVideoTitle: "Choose a video"
    )

    static let tr = Strings(
        subtitle: "Videoyu kusursuz döngüye çevir",
        dropTitle: "Videoyu buraya sürükle",
        dropSubtitle: "veya tıklayıp seç",
        change: "Değiştir",
        sectionMethod: "YÖNTEM",
        sectionSettings: "AYARLAR",
        xfadeAuto: "Geçiş (xfade)",
        xfadeOther: "Geçiş süresi (xfade)",
        xfadeHint: "0 = sert görünmez kesim",
        minLoop: "En kısa loop",
        quality: "Kalite (CRF)",
        qualityHint: "düşük = daha iyi",
        preset: "Preset",
        keepAudio: "Sesi koru",
        keepAudioAuto: "auto modunda ses her zaman atılır",
        keepAudioOther: "kapalıysa ses atılır",
        ffmpegMissing: "ffmpeg bulunamadı",
        ffmpegInstall: "Terminalde kurun:  brew install ffmpeg",
        readyPrefix: "Hazır",
        watch: "İzle",
        revealFinder: "Finder'da Göster",
        open: "Aç",
        openDefault: "Varsayılan Oynatıcıda Aç",
        log: "Günlük",
        createLoop: "Loop Oluştur",
        creating: "Oluşturuluyor…",
        secondsUnit: "sn",
        loopingBadge: "döngüde",
        close: "Kapat",
        chooseVideoTitle: "Video seç"
    )
}
