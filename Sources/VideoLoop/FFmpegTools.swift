import Foundation

/// ffmpeg / ffprobe ikililerinin yolları ve onları çalıştıran yardımcılar.
struct FFmpegTools: Sendable {
    let ffmpeg: String
    let ffprobe: String

    enum ToolError: LocalizedError {
        case notFound
        case failed(String)
        case probeFailed(String)
        case badOutput

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "ffmpeg / ffprobe bulunamadı. Kurmak için: brew install ffmpeg"
            case .failed(let msg):
                return msg.isEmpty ? "ffmpeg başarısız oldu." : "ffmpeg hatası:\n\(msg)"
            case .probeFailed(let msg):
                return "Video okunamadı:\n\(msg)"
            case .badOutput:
                return "Çıktı üretilemedi."
            }
        }
    }

    /// Önce uygulama paketine gömülü statik ikilileri, yoksa sistemdeki
    /// ffmpeg/ffprobe'u arar. (Finder'dan açılan uygulamanın PATH'inde homebrew
    /// dizinleri olmayabileceği için yaygın konumlar tek tek denenir.)
    static func locate() -> FFmpegTools? {
        guard let ffmpeg = find("ffmpeg"), let ffprobe = find("ffprobe") else { return nil }
        return FFmpegTools(ffmpeg: ffmpeg, ffprobe: ffprobe)
    }

    private static func find(_ name: String) -> String? {
        // 1) Uygulama paketine gömülü (Resources/bin) — başka Mac'te de çalışır.
        if let resources = Bundle.main.resourcePath {
            let bundled = "\(resources)/bin/\(name)"
            if FileManager.default.isExecutableFile(atPath: bundled) {
                return bundled
            }
        }
        // 2) Sistemdeki yaygın konumlar.
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "/opt/local/bin/\(name)",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        // Son çare: login shell üzerinden `which`.
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/bin/zsh")
        probe.arguments = ["-lc", "command -v \(name)"]
        let pipe = Pipe()
        probe.standardOutput = pipe
        probe.standardError = Pipe()
        do {
            try probe.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            probe.waitUntilExit()
            let path = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        } catch {
            return nil
        }
        return nil
    }

    /// PATH'i homebrew dizinlerini içerecek şekilde zenginleştirilmiş ortam.
    private var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extra = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        env["PATH"] = (env["PATH"].map { "\($0):\(extra)" }) ?? extra
        return env
    }

    // MARK: - Process çalıştırma

    /// stdout'u Data, stderr'i String olarak toplar (deadlock'tan kaçınmak için
    /// iki boruyu paralel okur). ffprobe ve ham kare çıkarımı için kullanılır.
    func capture(_ exe: String, _ args: [String]) throws -> (stdout: Data, stderr: String, code: Int32) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: exe)
        proc.arguments = args
        proc.environment = environment

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global().async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global().async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        try proc.run()
        group.wait()
        proc.waitUntilExit()

        return (outData, String(decoding: errData, as: UTF8.self), proc.terminationStatus)
    }

    /// ffmpeg'i akış halinde çalıştırır: stdout'tan `-progress` satırlarını
    /// parse ederek ilerleme bildirir, stderr satırlarını loga yollar.
    func runFFmpeg(
        _ args: [String],
        expectedDuration: Double?,
        log: @escaping @Sendable (String) -> Void,
        progress: @escaping @Sendable (Double) -> Void
    ) throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ffmpeg)
        proc.arguments = ["-y", "-hide_banner", "-loglevel", "error", "-progress", "pipe:1", "-nostats"] + args
        proc.environment = environment

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        var errCollected = ""
        let lock = NSLock()

        // stdout: ffmpeg -progress (key=value) satırları.
        var outBuf = ""
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            outBuf += String(decoding: data, as: UTF8.self)
            while let nl = outBuf.firstIndex(of: "\n") {
                let line = String(outBuf[..<nl])
                outBuf.removeSubrange(...nl)
                Self.parseProgress(line, expected: expectedDuration, progress: progress)
            }
        }

        // stderr: gerçek hata/uyarı satırları.
        var errBuf = ""
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            errBuf += String(decoding: data, as: UTF8.self)
            while let nl = errBuf.firstIndex(of: "\n") {
                let line = String(errBuf[..<nl])
                errBuf.removeSubrange(...nl)
                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    lock.lock(); errCollected += line + "\n"; lock.unlock()
                    log(line)
                }
            }
        }

        try proc.run()
        proc.waitUntilExit()

        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil

        if proc.terminationStatus != 0 {
            lock.lock(); let msg = errCollected; lock.unlock()
            throw ToolError.failed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func parseProgress(
        _ line: String,
        expected: Double?,
        progress: @escaping @Sendable (Double) -> Void
    ) {
        let parts = line.split(separator: "=", maxSplits: 1)
        guard parts.count == 2 else { return }
        let key = parts[0].trimmingCharacters(in: .whitespaces)
        let value = parts[1].trimmingCharacters(in: .whitespaces)

        if key == "progress", value == "end" {
            progress(1.0)
            return
        }
        guard let expected, expected > 0 else { return }
        if key == "out_time_us", let us = Double(value) {
            progress(min(0.995, (us / 1_000_000.0) / expected))
        } else if key == "out_time_ms", let ms = Double(value) {
            // bazı ffmpeg sürümlerinde out_time_ms aslında mikrosaniye verir.
            progress(min(0.995, (ms / 1_000_000.0) / expected))
        }
    }
}
