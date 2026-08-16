import AVFoundation

/// Synthesizes all sounds at runtime (sine-wave WAV buffers) — the app ships
/// with zero audio assets. Also handles spoken prompts and the silent
/// keep-alive loop that keeps the timer alive in the background.
final class SoundPlayer {
    static let shared = SoundPlayer()

    enum Cue: String, CaseIterable {
        case tick, prepare, work, rest, setRest, cooldown, custom, finish
    }

    private var players: [Cue: AVAudioPlayer] = [:]
    private let speech = AVSpeechSynthesizer()
    private var keepAlivePlayer: AVAudioPlayer?
    private var prepared = false

    var soundEnabled: Bool { SettingsKeys.defaultedBool(.soundEnabled) }
    var voiceEnabled: Bool { SettingsKeys.defaultedBool(.voiceEnabled) }

    /// Activates the playback session (so cues are audible even with the mute
    /// switch on) and pre-rolls every cue buffer.
    func prepare() {
        guard !prepared else { return }
        prepared = true
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio may be degraded, but the timer itself keeps working.
        }
        for cue in Cue.allCases {
            if let player = try? AVAudioPlayer(data: Self.wavData(for: cue)) {
                player.prepareToPlay()
                players[cue] = player
            }
        }
    }

    func play(_ cue: Cue) {
        guard soundEnabled else { return }
        prepare()
        players[cue]?.currentTime = 0
        players[cue]?.play()
    }

    func tick() { play(.tick) }

    func transition(for kind: PhaseKind) {
        switch kind {
        case .prepare: play(.prepare)
        case .work: play(.work)
        case .rest: play(.rest)
        case .setRest: play(.setRest)
        case .cooldown: play(.cooldown)
        case .custom: play(.custom)
        }
    }

    func finish() { play(.finish) }

    func speak(_ text: String) {
        guard voiceEnabled, !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.volume = 1
        utterance.pitchMultiplier = 1
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speech.speak(utterance)
    }

    // MARK: - Background keep-alive

    /// Loops near-silent audio so iOS keeps the process (and the timer) alive
    /// when the screen is locked or the app is backgrounded.
    func startKeepAlive() {
        guard SettingsKeys.defaultedBool(.backgroundTimer) else { return }
        prepare()
        guard keepAlivePlayer == nil else { return }
        if let player = try? AVAudioPlayer(data: Self.silenceData(seconds: 0.5)) {
            player.numberOfLoops = -1
            player.volume = 0.01
            player.play()
            keepAlivePlayer = player
        }
    }

    func stopKeepAlive() {
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
    }

    // MARK: - WAV synthesis

    private static let sampleRate = 44100

    private static func samples(for cue: Cue) -> [Float] {
        func tone(_ freq: Double, _ seconds: Double, gap: Double = 0) -> [Float] {
            let count = Int(Double(sampleRate) * seconds)
            let gapCount = Int(Double(sampleRate) * gap)
            var out = [Float](repeating: 0, count: count + gapCount)
            let attack = 0.008
            let release = min(0.06, seconds * 0.4)
            for i in 0..<count {
                let t = Double(i) / Double(sampleRate)
                var envelope = 1.0
                if t < attack {
                    envelope = t / attack
                } else if t > seconds - release {
                    envelope = (seconds - t) / release
                }
                out[i] = Float(sin(2.0 * Double.pi * freq * t) * 0.9 * envelope)
            }
            return out
        }

        switch cue {
        case .tick: return tone(1318, 0.07)
        case .prepare: return tone(660, 0.12)
        case .work: return tone(880, 0.2)
        case .rest: return tone(494, 0.2)
        case .setRest: return tone(587, 0.18)
        case .cooldown: return tone(523, 0.25)
        case .custom: return tone(784, 0.15)
        case .finish: return tone(880, 0.15, gap: 0.07) + tone(880, 0.05, gap: 0.07) + tone(1175, 0.3)
        }
    }

    private static func silenceData(seconds: Double) -> Data {
        let count = Int(Double(sampleRate) * seconds)
        return wavData(from: [Float](repeating: 0.0005, count: count))
    }

    private static func wavData(for cue: Cue) -> Data {
        wavData(from: samples(for: cue))
    }

    /// Minimal 16-bit mono PCM WAV container.
    private static func wavData(from samples: [Float]) -> Data {
        let byteCount = samples.count * 2
        var data = Data(capacity: 44 + byteCount)

        func appendUInt32(_ value: UInt32) {
            var le = value.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func appendUInt16(_ value: UInt16) {
            var le = value.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        appendUInt32(UInt32(36 + byteCount))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        appendUInt32(16)
        appendUInt16(1) // PCM
        appendUInt16(1) // mono
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate) * 2) // byte rate
        appendUInt16(2) // block align
        appendUInt16(16) // bits per sample
        data.append(contentsOf: Array("data".utf8))
        appendUInt32(UInt32(byteCount))

        for sample in samples {
            let clamped = max(-1.0, min(1.0, Double(sample)))
            var pcm = Int16(clamped * 32767.0)
            withUnsafeBytes(of: &pcm) { data.append(contentsOf: $0) }
        }
        return data
    }
}
