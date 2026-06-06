import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var engine = LoopEngine()

    @State private var inputURL: URL?
    @State private var outputURL: URL?
    @State private var options = LoopOptions()
    @State private var isTargeted = false
    @State private var showLog = false
    @State private var showPreview = false

    private let accent = Color(red: 0.45, green: 0.36, blue: 0.96)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    dropZone
                    modeSection
                    optionsSection
                    if !engine.toolsAvailable { ffmpegWarning }
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showPreview) {
            if let result = engine.resultURL {
                LoopPlayerView(url: result) { showPreview = false }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            logoImage
            VStack(alignment: .leading, spacing: 1) {
                Text("VideoLoop")
                    .font(.system(size: 16, weight: .semibold))
                Text("Videoyu kusursuz döngüye çevir")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    /// Paketteki logo.png; yoksa SF Symbol'a düşer.
    @ViewBuilder
    private var logoImage: some View {
        if let path = Bundle.main.path(forResource: "logo", ofType: "png"),
           let nsImage = NSImage(contentsOfFile: path) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
        } else {
            Image(systemName: "infinity")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(accent)
        }
    }

    // MARK: - Drop zone

    private var dropZone: some View {
        VStack(spacing: 10) {
            if let inputURL {
                HStack(spacing: 12) {
                    Image(systemName: "film.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(inputURL.lastPathComponent)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(inputURL.deletingLastPathComponent().path)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Değiştir") { pickInput() }
                        .buttonStyle(.borderless)
                }
                .padding(16)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("Videoyu buraya sürükle")
                        .font(.system(size: 13, weight: .medium))
                    Text("veya tıklayıp seç")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .contentShape(Rectangle())
                .onTapGesture { pickInput() }
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? accent.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? accent : Color.secondary.opacity(0.25),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: inputURL == nil ? [6] : [])
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Mod seçimi

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YÖNTEM")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(LoopMode.allCases) { mode in
                    modeCard(mode)
                }
            }
        }
    }

    private func modeCard(_ mode: LoopMode) -> some View {
        let selected = options.mode == mode
        return Button {
            options.mode = mode
            options.xfade = mode.defaultXfade
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? accent : .secondary)
                    Text(mode.title)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                    }
                }
                Text(mode.summary)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? accent.opacity(0.10) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? accent.opacity(0.6) : Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ayarlar

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AYARLAR")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            if options.mode.usesXfade {
                sliderRow(
                    title: options.mode == .auto ? "Geçiş (xfade)" : "Geçiş süresi (xfade)",
                    value: $options.xfade, range: 0...3, step: 0.1,
                    format: "%.1f sn",
                    hint: options.mode == .auto ? "0 = sert görünmez kesim" : nil
                )
            }

            if options.mode == .auto {
                sliderRow(
                    title: "En kısa loop",
                    value: $options.minLoop, range: 0.5...10, step: 0.5,
                    format: "%.1f sn", hint: nil
                )
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kalite (CRF)").font(.system(size: 12))
                    HStack {
                        Slider(value: Binding(
                            get: { Double(options.crf) },
                            set: { options.crf = Int($0) }
                        ), in: 12...30, step: 1)
                        Text("\(options.crf)")
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 24, alignment: .trailing)
                    }
                    Text("düşük = daha iyi").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preset").font(.system(size: 12))
                    Picker("", selection: $options.preset) {
                        ForEach(LoopOptions.presets, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
                .frame(width: 160)
            }

            Toggle(isOn: $options.includeAudio) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sesi koru").font(.system(size: 12))
                    Text(options.mode == .auto ? "auto modunda ses her zaman atılır" : "kapalıysa ses atılır")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .tint(accent)
            .disabled(options.mode == .auto)
        }
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>,
                           step: Double, format: String, hint: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 12))
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step).tint(accent)
            if let hint {
                Text(hint).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }

    private var ffmpegWarning: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("ffmpeg bulunamadı").font(.system(size: 12, weight: .medium))
                Text("Terminalde kurun:  brew install ffmpeg")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
    }

    // MARK: - Footer (ilerleme + aksiyon)

    private var footer: some View {
        VStack(spacing: 10) {
            if engine.isRunning || engine.progress > 0 {
                VStack(spacing: 4) {
                    ProgressView(value: engine.progress).tint(accent)
                    HStack {
                        Text(engine.logLines.last ?? "")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(engine.progress * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let error = engine.lastError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                    Text(error).font(.system(size: 11)).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }

            if let result = engine.resultURL, !engine.isRunning {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Hazır: \(result.lastPathComponent)").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button {
                        showPreview = true
                    } label: {
                        Label("İzle", systemImage: "play.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    Button("Finder'da Göster") { NSWorkspace.shared.activateFileViewerSelecting([result]) }
                        .buttonStyle(.borderless)
                }
            }

            HStack(spacing: 12) {
                Button {
                    showLog.toggle()
                } label: {
                    Label("Günlük", systemImage: showLog ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .disabled(engine.logLines.isEmpty)

                Spacer()

                Button {
                    start()
                } label: {
                    HStack(spacing: 6) {
                        if engine.isRunning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "infinity")
                        }
                        Text(engine.isRunning ? "Oluşturuluyor…" : "Loop Oluştur")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(minWidth: 140)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(inputURL == nil || engine.isRunning || !engine.toolsAvailable)
            }

            if showLog {
                ScrollView {
                    Text(engine.logLines.joined(separator: "\n"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                }
                .frame(height: 120)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
            }
        }
        .padding(16)
    }

    // MARK: - Aksiyonlar

    private func pickInput() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            setInput(url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let u = item as? URL {
                url = u
            }
            if let url {
                DispatchQueue.main.async { setInput(url) }
            }
        }
        return true
    }

    private func setInput(_ url: URL) {
        inputURL = url
        let base = url.deletingPathExtension().lastPathComponent
        outputURL = url.deletingLastPathComponent().appendingPathComponent("\(base)_loop.mp4")
        engine.resultURL = nil
        engine.lastError = nil
        engine.progress = 0
    }

    private func start() {
        guard let inputURL else { return }

        // Çıktı için kaydetme paneli (varsayılan: <ad>_loop.mp4).
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = outputURL?.lastPathComponent
            ?? "\(inputURL.deletingPathExtension().lastPathComponent)_loop.mp4"
        panel.directoryURL = inputURL.deletingLastPathComponent()
        guard panel.runModal() == .OK, let out = panel.url else { return }

        outputURL = out
        engine.run(input: inputURL, output: out, options: options)
    }
}
