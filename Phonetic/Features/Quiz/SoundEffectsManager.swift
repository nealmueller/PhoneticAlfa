import Foundation
import AVFoundation

@MainActor
final class SoundEffectsManager {
    private var activePlayers: [AVAudioPlayer] = []

    func playCorrect() {
        // Intentionally silent: quiz should not emit click/tap sounds.
    }

    func playIncorrect() {
        // Intentionally silent: quiz should not emit click/tap sounds.
    }

    func playTrophy() {
        playSequence([
            (frequency: 740.0, duration: 0.08),
            (frequency: 988.0, duration: 0.10),
            (frequency: 1244.0, duration: 0.16)
        ], volume: 0.42)
    }

    func playPerfectScore() {
        playSequence([
            (frequency: 660.0, duration: 0.08),
            (frequency: 880.0, duration: 0.10),
            (frequency: 1108.0, duration: 0.10),
            (frequency: 1320.0, duration: 0.18),
            (frequency: 1568.0, duration: 0.22)
        ], volume: 0.46)
    }

    private func playSequence(_ notes: [(frequency: Double, duration: Double)], volume: Float) {
        guard ProcessInfo.processInfo.environment["UITEST_DISABLE_SPEECH"] != "1" else { return }
        do {
            let data = try Self.makeWaveData(notes: notes)
            let player = try AVAudioPlayer(data: data)
            player.volume = volume
            activePlayers.append(player)
            player.play()
            let totalDuration = notes.map(\.duration).reduce(0, +) + (Double(notes.count) * 0.012) + 0.25
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) { [weak self] in
                self?.activePlayers.removeAll { $0 === player }
            }
        } catch {
            // Best-effort effects only.
        }
    }

    private static func makeWaveData(
        notes: [(frequency: Double, duration: Double)],
        sampleRate: Int = 44_100
    ) throws -> Data {
        let twoPi = 2.0 * Double.pi
        let fadeSamples = Int(Double(sampleRate) * 0.01)
        var pcm = Data()

        for note in notes {
            let sampleCount = max(1, Int(note.duration * Double(sampleRate)))
            for i in 0..<sampleCount {
                let t = Double(i) / Double(sampleRate)
                let base = sin(twoPi * note.frequency * t)

                let attack = min(1.0, Double(i) / Double(max(1, fadeSamples)))
                let release = min(1.0, Double(sampleCount - i) / Double(max(1, fadeSamples)))
                let envelope = max(0, min(1, min(attack, release)))

                let sample = Int16(max(-32767, min(32767, base * envelope * 18000)))
                var little = sample.littleEndian
                withUnsafeBytes(of: &little) { pcm.append(contentsOf: $0) }
            }
            let silenceSamples = Int(Double(sampleRate) * 0.012)
            for _ in 0..<silenceSamples {
                var zero = Int16(0).littleEndian
                withUnsafeBytes(of: &zero) { pcm.append(contentsOf: $0) }
            }
        }

        let dataChunkSize = UInt32(pcm.count)
        let byteRate = UInt32(sampleRate * 2)
        let blockAlign: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let chunkSize = UInt32(36) + dataChunkSize

        var wav = Data()
        wav.append(contentsOf: Array("RIFF".utf8))
        wav.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian, Array.init))
        wav.append(contentsOf: Array("WAVE".utf8))
        wav.append(contentsOf: Array("fmt ".utf8))
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian, Array.init))
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian, Array.init))
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian, Array.init))
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian, Array.init))
        wav.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian, Array.init))
        wav.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian, Array.init))
        wav.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian, Array.init))
        wav.append(contentsOf: Array("data".utf8))
        wav.append(contentsOf: withUnsafeBytes(of: dataChunkSize.littleEndian, Array.init))
        wav.append(pcm)
        return wav
    }
}
