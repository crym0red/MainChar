import AVFoundation

/// Tiny synthesized sound bank for the battle royale (no audio assets needed).
final class BRAudio {
    static let shared = BRAudio()
    var volume: Float = 0.8
    private let eng = AVAudioEngine()
    private var nodes: [AVAudioPlayerNode] = []
    private var bufs: [String: AVAudioPCMBuffer] = [:]
    private var next = 0
    private var ok = false
    private let rate: Double = 22050

    private init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { return }
        for _ in 0..<12 {
            let n = AVAudioPlayerNode()
            eng.attach(n)
            eng.connect(n, to: eng.mainMixerNode, format: fmt)
            nodes.append(n)
        }
        build(fmt)
        do {
            try eng.start()
            ok = true
        } catch {}
    }

    private func noise() -> Double { Double.random(in: -1...1) }

    private func make(_ name: String, _ dur: Double, _ fmt: AVAudioFormat, _ gen: (Double) -> Double) {
        let n = AVAudioFrameCount(dur * rate)
        guard let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n), let ch = b.floatChannelData?[0] else { return }
        b.frameLength = n
        for i in 0..<Int(n) {
            let t = Double(i) / rate
            let fade = min(1, (dur - t) * 40)
            ch[i] = Float(max(-1, min(1, gen(t) * fade)))
        }
        bufs[name] = b
    }

    private func build(_ f: AVAudioFormat) {
        let tau = 2 * Double.pi
        make("shot_pistol", 0.22, f) { t in (self.noise() * exp(-t * 30) * 0.8 + sin(tau * 150 * t) * exp(-t * 22) * 0.7) * 0.9 }
        make("shot_smg", 0.16, f) { t in (self.noise() * exp(-t * 38) * 0.8 + sin(tau * 210 * t) * exp(-t * 28) * 0.6) * 0.8 }
        make("shot_rifle", 0.3, f) { t in (self.noise() * exp(-t * 20) * 0.85 + sin(tau * 105 * t) * exp(-t * 14) * 0.8) * 0.95 }
        make("shot_shotgun", 0.45, f) { t in (self.noise() * exp(-t * 11) * 0.9 + sin(tau * 62 * t) * exp(-t * 9) * 0.9) * 1.0 }
        make("shot_sup", 0.14, f) { t in (self.noise() * exp(-t * 55) * 0.5 + sin(tau * 90 * t) * exp(-t * 40) * 0.3) * 0.6 }
        make("hit", 0.05, f) { t in sin(tau * 1700 * t) * exp(-t * 60) * 0.6 }
        make("head", 0.16, f) { t in (sin(tau * 2400 * t) + sin(tau * 3100 * t) * 0.6) * exp(-t * 22) * 0.5 }
        make("kill", 0.3, f) { t in (t < 0.12 ? sin(tau * 900 * t) : sin(tau * 1350 * t)) * exp(-t * 9) * 0.55 }
        make("hurt", 0.18, f) { t in (sin(tau * 110 * t) * 0.8 + self.noise() * 0.3) * exp(-t * 16) * 0.8 }
        make("reload", 0.3, f) { t in
            let a = t < 0.03 ? self.noise() * 0.6 : 0
            let b = (t > 0.17 && t < 0.2) ? self.noise() * 0.7 : 0
            return a + b + sin(tau * 300 * t) * exp(-t * 30) * 0.2
        }
        make("step", 0.09, f) { t in (self.noise() * 0.35 + sin(tau * 85 * t) * 0.7) * exp(-t * 45) }
        make("boom", 1.0, f) { t in (self.noise() * exp(-t * 5) * 0.8 + sin(tau * 52 * t) * exp(-t * 3.5) * 0.9) }
        make("pop", 0.25, f) { t in (self.noise() * 0.5 + sin(tau * 160 * t) * 0.5) * exp(-t * 14) }
        make("siren", 0.9, f) { t in sin(tau * (600 + 280 * sin(tau * 1.4 * t)) * t) * 0.35 * (t < 0.1 ? t * 10 : 1) }
        make("plate", 0.35, f) { t in sin(tau * (400 + 700 * t) * t) * 0.4 * exp(-t * 3) }
        make("chute", 0.45, f) { t in self.noise() * 0.35 * sin(Double.pi * min(1, t / 0.45)) }
        make("throw", 0.2, f) { t in self.noise() * 0.25 * sin(Double.pi * min(1, t / 0.2)) }
        make("pickup", 0.14, f) { t in (t < 0.06 ? sin(tau * 900 * t) : sin(tau * 1300 * t)) * exp(-t * 14) * 0.45 }
        make("ping", 0.3, f) { t in sin(tau * 1000 * t) * exp(-t * 10) * 0.45 }
        make("engine", 0.26, f) { t in (sin(tau * 62 * t) + 0.5 * sin(tau * 124 * t) + 0.25 * self.noise()) * 0.38 }
    }

    func play(_ name: String, vol: Float = 1, pan: Float = 0) {
        guard ok, let b = bufs[name] else { return }
        let v = vol * volume
        if v < 0.02 { return }
        let n = nodes[next]
        next = (next + 1) % nodes.count
        n.stop()
        n.volume = min(1, v)
        n.pan = max(-1, min(1, pan))
        n.scheduleBuffer(b, at: nil, options: [], completionHandler: nil)
        n.play()
    }
}
