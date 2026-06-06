import SwiftUI
import AVKit

/// AVKit'in AppKit oynatıcısını SwiftUI'a köprüler. (SwiftUI `VideoPlayer`,
/// SPM ile derlenen çıplak uygulamada metadata hatasıyla çöküyor; `AVPlayerView`
/// güvenilir ve native oynatma kontrolleri sağlıyor.)
struct PlayerContainer: NSViewRepresentable {
    let player: AVQueuePlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player { nsView.player = player }
    }
}

/// Çıktıyı kesintisiz döngüde oynatır — loop dikişinin gerçekten görünmez
/// olup olmadığını yerinde test etmek için. `AVPlayerLooper` sayesinde geçiş
/// kare kaybı olmadan tekrarlar.
@MainActor
final class LoopPlayerModel: ObservableObject {
    let player: AVQueuePlayer
    private let looper: AVPlayerLooper

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        queue.isMuted = true
        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
    }

    func play() { player.play() }
    func stop() { player.pause() }
}

struct LoopPlayerView: View {
    let url: URL
    var onClose: () -> Void

    @StateObject private var model: LoopPlayerModel
    private let accent = Color(red: 0.45, green: 0.36, blue: 0.96)

    init(url: URL, onClose: @escaping () -> Void) {
        self.url = url
        self.onClose = onClose
        _model = StateObject(wrappedValue: LoopPlayerModel(url: url))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "infinity")
                    .foregroundStyle(accent)
                Text(url.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("döngüde")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Button {
                    model.stop()
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            PlayerContainer(player: model.player)
                .frame(minWidth: 480, minHeight: 320)

            HStack(spacing: 10) {
                Button("Finder'da Göster") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.borderless)
                Button("Varsayılan Oynatıcıda Aç") {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.borderless)
                Spacer()
                Button("Kapat") {
                    model.stop()
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(minWidth: 520, minHeight: 420)
        .onAppear { model.play() }
        .onDisappear { model.stop() }
    }
}
