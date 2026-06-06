import Foundation

/// videoloop.py'nin Swift karşılığı: probe, kare-benzerliği analizi ve dört mod.
struct Looper: Sendable {
    let tools: FFmpegTools
    let log: @Sendable (String) -> Void
    let progress: @Sendable (Double) -> Void

    // MARK: - Genel akış

    /// Tüm işi yürütür ve üretilen çıktının yolunu döndürür.
    func process(input: String, output: String, options: LoopOptions) throws -> String {
        let info = try probe(input)
        log(String(format: "Video: %.2fs, %.2f fps | mod: %@ | ses: %@",
                   info.duration, info.fps, options.mode.title,
                   options.includeAudio && info.hasAudio ? "korunuyor" : "atılıyor"))

        let audio = options.includeAudio && info.hasAudio

        switch options.mode {
        case .crossfade:
            try buildCrossfade(inp: input, out: output, dur: info.duration,
                               xfade: options.xfade, fps: info.fps, audio: audio, options: options)
        case .swap:
            try buildSwap(inp: input, out: output, dur: info.duration,
                          xfade: options.xfade, fps: info.fps, audio: audio, options: options)
        case .boomerang:
            try buildBoomerang(inp: input, out: output, dur: info.duration,
                               fps: info.fps, audio: audio, options: options)
        case .auto:
            try buildAuto(inp: input, out: output, info: info, options: options)
        }

        let outInfo = try probe(output)
        log(String(format: "✓ Tamam: %@  (%.2fs)", output, outInfo.duration))
        progress(1.0)
        return output
    }

    // MARK: - probe

    func probe(_ path: String) throws -> VideoInfo {
        let (out, err, code) = try tools.capture(tools.ffprobe, [
            "-v", "error", "-print_format", "json",
            "-show_format", "-show_streams", path,
        ])
        guard code == 0 else { throw FFmpegTools.ToolError.probeFailed(err) }
        guard let json = try? JSONSerialization.jsonObject(with: out) as? [String: Any] else {
            throw FFmpegTools.ToolError.probeFailed("ffprobe JSON çözülemedi.")
        }

        var duration = 0.0
        if let format = json["format"] as? [String: Any],
           let d = (format["duration"] as? String).flatMap(Double.init) {
            duration = d
        }

        var fps = 30.0
        var hasAudio = false
        if let streams = json["streams"] as? [[String: Any]] {
            for s in streams {
                let type = s["codec_type"] as? String
                if type == "video" {
                    let rate = (s["avg_frame_rate"] as? String) ?? (s["r_frame_rate"] as? String) ?? "30/1"
                    let comps = rate.split(separator: "/")
                    if comps.count == 2, let num = Double(comps[0]), let den = Double(comps[1]), den != 0 {
                        fps = num / den
                    }
                    if duration <= 0, let d = (s["duration"] as? String).flatMap(Double.init) {
                        duration = d
                    }
                } else if type == "audio" {
                    hasAudio = true
                }
            }
        }

        guard duration > 0 else { throw FFmpegTools.ToolError.probeFailed("Video süresi belirlenemedi.") }
        return VideoInfo(duration: duration, fps: fps, hasAudio: hasAudio)
    }

    // MARK: - encode parametreleri

    private func encodeOptions(fps: Double, audio: Bool, options: LoopOptions) -> [String] {
        var o = [
            "-c:v", "libx264", "-preset", options.preset, "-crf", String(options.crf),
            "-pix_fmt", "yuv420p", "-r", String(format: "%.6f", fps),
            "-movflags", "+faststart",
        ]
        if audio {
            o += ["-c:a", "aac", "-b:a", "192k"]
        } else {
            o += ["-an"]
        }
        return o
    }

    // MARK: - auto: en iyi loop penceresi (kare benzerliği)

    /// Videoyu 32x18 gri karelere indirip en çok benzeyen (başlangıç, bitiş)
    /// çiftini bulur. (t_start, t_end) saniye döndürür.
    func detectLoopWindow(path: String, dur: Double, minLoop: Double, headFrac: Double = 0.20) throws -> (Double, Double) {
        let W = 32, H = 18
        let frameSize = W * H
        let maxFrames = 800.0
        let sampleFps = min(15.0, max(2.0, maxFrames / dur))

        log(String(format: "  analiz: ~%.1f fps örnekleme, %dx%d gri kareler...", sampleFps, W, H))

        let (out, err, code) = try tools.capture(tools.ffmpeg, [
            "-v", "error", "-i", path,
            "-vf", "fps=\(sampleFps),scale=\(W):\(H),format=gray",
            "-f", "rawvideo", "-pix_fmt", "gray", "-",
        ])
        guard code == 0 else { throw FFmpegTools.ToolError.failed("kare analizi başarısız:\n\(err)") }

        let bytes = [UInt8](out)
        let n = bytes.count / frameSize
        guard n >= 4 else {
            throw FFmpegTools.ToolError.failed("Analiz için yeterli kare yok (video çok kısa).")
        }

        // Ortalama mutlak fark.
        func mad(_ a: Int, _ b: Int) -> Int {
            var sum = 0
            let baseA = a * frameSize
            let baseB = b * frameSize
            for i in 0..<frameSize {
                sum += abs(Int(bytes[baseA + i]) - Int(bytes[baseB + i]))
            }
            return sum
        }

        let minGap = max(1, Int((minLoop * sampleFps).rounded()))

        // Başlangıç adayları: ilk %headFrac içinde en fazla 12 nokta.
        let headEnd = max(1, Int(Double(n) * headFrac))
        let nStarts = min(12, headEnd)
        let step = max(1, headEnd / nStarts)
        var startCands = Array(stride(from: 0, to: headEnd, by: step).prefix(nStarts))
        if startCands.isEmpty { startCands = [0] }

        var best: (score: Double, s: Int, e: Int)?
        for s in startCands {
            let sNext = s + 1 < n ? s + 1 : s
            let e0 = s + minGap
            guard e0 < n else { continue }
            for e in e0..<n {
                let eNext = e + 1 < n ? e + 1 : e
                let score = Double(mad(s, e)) + 0.5 * Double(mad(sNext, eNext))
                if best == nil || score < best!.score {
                    best = (score, s, e)
                }
            }
        }

        guard let result = best else {
            throw FFmpegTools.ToolError.failed("Uygun loop penceresi bulunamadı. min-loop değerini düşürün.")
        }

        let tStart = Double(result.s) / sampleFps
        let tEnd = Double(result.e) / sampleFps
        log(String(format: "  bulundu: %.2fs → %.2fs  (loop uzunluğu %.2fs)", tStart, tEnd, tEnd - tStart))
        return (tStart, tEnd)
    }

    // MARK: - Modlar

    func buildCrossfade(inp: String, out: String, dur: Double, xfade: Double,
                        fps: Double, audio: Bool, options: LoopOptions) throws {
        guard xfade < dur / 2 else {
            throw FFmpegTools.ToolError.failed(String(format: "xfade (%.2fs) çok uzun. Video %.1fs; yarısından kısa olmalı.", xfade, dur))
        }
        let offset = dur - 2 * xfade
        var vf = "[0:v]trim=start=\(xfade),setpts=PTS-STARTPTS[v1];"
            + "[0:v]trim=start=0:end=\(xfade),setpts=PTS-STARTPTS[v2];"
            + "[v1][v2]xfade=transition=fade:duration=\(xfade):offset=\(offset)[v]"
        var maps = ["-map", "[v]"]
        if audio {
            vf += ";[0:a]atrim=start=\(xfade),asetpts=PTS-STARTPTS[a1];"
                + "[0:a]atrim=start=0:end=\(xfade),asetpts=PTS-STARTPTS[a2];"
                + "[a1][a2]acrossfade=d=\(xfade):c1=tri:c2=tri[a]"
            maps += ["-map", "[a]"]
        }
        let args = ["-i", inp, "-filter_complex", vf] + maps + encodeOptions(fps: fps, audio: audio, options: options) + [out]
        log("crossfade loop oluşturuluyor...")
        try tools.runFFmpeg(args, expectedDuration: dur - xfade, log: log, progress: progress)
    }

    func buildSwap(inp: String, out: String, dur: Double, xfade: Double,
                   fps: Double, audio: Bool, options: LoopOptions) throws {
        let mid = dur / 2.0
        guard xfade < mid else {
            throw FFmpegTools.ToolError.failed(String(format: "xfade (%.2fs) çok uzun (yarı süre %.1fs).", xfade, mid))
        }
        let offset = mid - xfade
        var vf = "[0:v]trim=start=\(mid),setpts=PTS-STARTPTS[vb];"
            + "[0:v]trim=start=0:end=\(mid),setpts=PTS-STARTPTS[va];"
            + "[vb][va]xfade=transition=fade:duration=\(xfade):offset=\(offset)[v]"
        var maps = ["-map", "[v]"]
        if audio {
            vf += ";[0:a]atrim=start=\(mid),asetpts=PTS-STARTPTS[ab];"
                + "[0:a]atrim=start=0:end=\(mid),asetpts=PTS-STARTPTS[aa];"
                + "[ab][aa]acrossfade=d=\(xfade):c1=tri:c2=tri[a]"
            maps += ["-map", "[a]"]
        }
        let args = ["-i", inp, "-filter_complex", vf] + maps + encodeOptions(fps: fps, audio: audio, options: options) + [out]
        log("swap loop oluşturuluyor...")
        try tools.runFFmpeg(args, expectedDuration: dur - xfade, log: log, progress: progress)
    }

    func buildBoomerang(inp: String, out: String, dur: Double,
                        fps: Double, audio: Bool, options: LoopOptions) throws {
        var vf = "[0:v]reverse[r];[0:v][r]concat=n=2:v=1[v]"
        var maps = ["-map", "[v]"]
        if audio {
            vf += ";[0:a]asetpts=PTS-STARTPTS[a1];[0:a]asetpts=PTS-STARTPTS[a2];[a1][a2]concat=n=2:v=0:a=1[a]"
            maps += ["-map", "[a]"]
        }
        let args = ["-i", inp, "-filter_complex", vf] + maps + encodeOptions(fps: fps, audio: audio, options: options) + [out]
        log("boomerang loop oluşturuluyor...")
        try tools.runFFmpeg(args, expectedDuration: dur * 2, log: log, progress: progress)
    }

    func buildAuto(inp: String, out: String, info: VideoInfo, options: LoopOptions) throws {
        log("auto: en iyi loop noktası aranıyor...")
        let (tStart, tEnd) = try detectLoopWindow(path: inp, dur: info.duration, minLoop: options.minLoop)
        let segDur = tEnd - tStart
        let audio = false // auto'da ses her zaman atılır (kare hassasiyeti için yeniden kodlanır).

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("videoloop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let seg = tmpDir.appendingPathComponent("segment.mp4").path

        log("  loop penceresi kesiliyor...")
        let cutArgs = ["-ss", String(format: "%.4f", tStart), "-i", inp, "-t", String(format: "%.4f", segDur)]
            + encodeOptions(fps: info.fps, audio: audio, options: options) + [seg]
        try tools.runFFmpeg(cutArgs, expectedDuration: segDur, log: log, progress: progress)

        if options.xfade > 0 {
            let segInfo = try probe(seg)
            let xf = min(options.xfade, segInfo.duration / 2.5)
            try buildCrossfade(inp: seg, out: out, dur: segInfo.duration,
                               xfade: xf, fps: info.fps, audio: audio, options: options)
        } else {
            if FileManager.default.fileExists(atPath: out) {
                try FileManager.default.removeItem(atPath: out)
            }
            try FileManager.default.moveItem(atPath: seg, toPath: out)
            guard FileManager.default.fileExists(atPath: out) else {
                throw FFmpegTools.ToolError.badOutput
            }
        }
    }
}
