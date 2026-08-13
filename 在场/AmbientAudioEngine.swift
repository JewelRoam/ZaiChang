import AVFoundation
import Combine
import Darwin

@MainActor
protocol AmbientAudioControlling: AnyObject {
    var currentPreset: AmbientPreset { get }
    var isEnabled: Bool { get }

    func start(preset: AmbientPreset, enabled: Bool)
    func setPreset(_ preset: AmbientPreset)
    func setEnabled(_ enabled: Bool)
    func setTemporarilyMuted(_ muted: Bool)
    func stop()
}

@MainActor
final class AmbientAudioEngine: ObservableObject, AmbientAudioControlling {
    @Published private(set) var lastError: String?

    private let engine = AVAudioEngine()
    private let masterMixer = AVAudioMixerNode()
    private let players = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private let sceneMixers = [AVAudioMixerNode(), AVAudioMixerNode()]
    private let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 48_000,
        channels: 2,
        interleaved: false
    )!
    private var buffers: [AmbientPreset: AVAudioPCMBuffer] = [:]
    private var activeSlot = 0
    private var isConfigured = false
    private var isTemporarilyMuted = false
    private var crossfadeTask: Task<Void, Never>?
    private var volumeFadeTask: Task<Void, Never>?

    private(set) var currentPreset: AmbientPreset = .rain
    private(set) var isEnabled = true

    deinit {
        crossfadeTask?.cancel()
        volumeFadeTask?.cancel()
        engine.stop()
    }

    func start(preset: AmbientPreset, enabled: Bool) {
        currentPreset = preset
        isEnabled = enabled

        // Ambient audio is opt-in. Do not construct or start AVAudioEngine
        // while it is disabled; this keeps app launch silent and avoids
        // asking macOS's sandboxed audio services for an output session.
        guard enabled else {
            stop()
            return
        }

        configureIfNeeded()
        guard lastError == nil else { return }

        schedule(preset, on: activeSlot)
        sceneMixers[activeSlot].outputVolume = 1
        sceneMixers[1 - activeSlot].outputVolume = 0
        masterMixer.outputVolume = targetMasterVolume

        do {
            engine.prepare()
            try engine.start()
            if !players[activeSlot].isPlaying {
                players[activeSlot].play()
            }
        } catch {
            lastError = "环境声暂时无法播放：\(error.localizedDescription)"
        }
    }

    func setPreset(_ preset: AmbientPreset) {
        guard preset != currentPreset else { return }
        currentPreset = preset
        guard isConfigured, engine.isRunning else { return }

        let oldSlot = activeSlot
        let newSlot = 1 - oldSlot
        players[newSlot].stop()
        schedule(preset, on: newSlot)
        sceneMixers[newSlot].outputVolume = 0
        players[newSlot].play()
        activeSlot = newSlot
        crossfade(from: oldSlot, to: newSlot, duration: 0.55)
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled

        if enabled {
            // A disabled engine is intentionally torn down at launch. Start
            // it lazily when the user explicitly enables ambient audio.
            start(preset: currentPreset, enabled: true)
            return
        }

        fadeMaster(to: targetMasterVolume, duration: enabled ? 0.8 : 0.45)
    }

    func setTemporarilyMuted(_ muted: Bool) {
        guard muted != isTemporarilyMuted else { return }
        isTemporarilyMuted = muted
        fadeMaster(to: targetMasterVolume, duration: muted ? 0.18 : 0.45)
    }

    func stop() {
        crossfadeTask?.cancel()
        volumeFadeTask?.cancel()
        players.forEach { $0.stop() }
        engine.stop()
    }

    private var targetMasterVolume: Float {
        isEnabled && !isTemporarilyMuted ? 0.24 : 0
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        lastError = nil
        engine.attach(masterMixer)
        for index in players.indices {
            engine.attach(players[index])
            engine.attach(sceneMixers[index])
            engine.connect(players[index], to: sceneMixers[index], format: format)
            engine.connect(sceneMixers[index], to: masterMixer, format: format)
        }
        engine.connect(masterMixer, to: engine.mainMixerNode, format: format)
        isConfigured = true
    }

    private func schedule(_ preset: AmbientPreset, on slot: Int) {
        let buffer = buffers[preset] ?? AmbientBufferFactory.make(preset: preset, format: format)
        buffers[preset] = buffer
        players[slot].scheduleBuffer(buffer, at: nil, options: .loops)
    }

    private func crossfade(from oldSlot: Int, to newSlot: Int, duration: TimeInterval) {
        crossfadeTask?.cancel()
        crossfadeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let steps = 28
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                let progress = Float(step) / Float(steps)
                sceneMixers[oldSlot].outputVolume = 1 - progress
                sceneMixers[newSlot].outputVolume = progress
                try? await Task.sleep(for: .milliseconds(Int(duration * 1_000) / steps))
            }
            guard !Task.isCancelled else { return }
            players[oldSlot].stop()
            sceneMixers[oldSlot].outputVolume = 0
            sceneMixers[newSlot].outputVolume = 1
        }
    }

    private func fadeMaster(to target: Float, duration: TimeInterval) {
        guard isConfigured else { return }
        volumeFadeTask?.cancel()
        let start = masterMixer.outputVolume
        volumeFadeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let steps = 24
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                let progress = Float(step) / Float(steps)
                masterMixer.outputVolume = start + (target - start) * progress
                try? await Task.sleep(for: .milliseconds(Int(duration * 1_000) / steps))
            }
            guard !Task.isCancelled else { return }
            masterMixer.outputVolume = target
        }
    }
}

private enum AmbientBufferFactory {
    private static let duration: Double = 14

    static func make(preset: AmbientPreset, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        guard let channels = buffer.floatChannelData else { return buffer }

        var left = Array(repeating: Float.zero, count: Int(frameCount))
        var right = Array(repeating: Float.zero, count: Int(frameCount))
        switch preset {
        case .quiet:
            break
        case .rain:
            renderRain(left: &left, right: &right, sampleRate: format.sampleRate)
        case .forest:
            renderForest(left: &left, right: &right, sampleRate: format.sampleRate)
        case .fireplace:
            renderFireplace(left: &left, right: &right, sampleRate: format.sampleRate)
        }

        let edgeFrames = max(1, Int(format.sampleRate * 0.03))
        for index in left.indices {
            let fadeIn = Float(index) / Float(edgeFrames)
            let fadeOut = Float(left.count - 1 - index) / Float(edgeFrames)
            let edgeGain = min(1, min(fadeIn, fadeOut))
            channels[0][index] = softLimit(left[index]) * edgeGain
            channels[1][index] = softLimit(right[index]) * edgeGain
        }
        return buffer
    }

    private static func renderRain(left: inout [Float], right: inout [Float], sampleRate: Double) {
        var leftNoise = Noise(seed: 0xA11CE)
        var rightNoise = Noise(seed: 0xA11CF)
        var leftLow = OnePoleLowPass(cutoff: 7_200, sampleRate: sampleRate)
        var rightLow = OnePoleLowPass(cutoff: 7_000, sampleRate: sampleRate)
        var leftBrown: Float = 0
        var rightBrown: Float = 0

        for index in left.indices {
            let whiteL = leftNoise.nextSigned()
            let whiteR = rightNoise.nextSigned()
            leftBrown = (leftBrown + 0.018 * whiteL) / 1.018
            rightBrown = (rightBrown + 0.018 * whiteR) / 1.018
            left[index] = leftLow.process(whiteL) * 0.23 + leftBrown * 0.62
            right[index] = rightLow.process(whiteR) * 0.23 + rightBrown * 0.62
        }

        var events = Noise(seed: 0xD09)
        var start = Int(sampleRate * 0.35)
        while start < left.count {
            let length = min(Int(sampleRate * 0.11), left.count - start)
            let frequency = 760 + Double(events.nextUnit()) * 620
            let pan = events.nextSigned() * 0.45
            addChirp(
                left: &left,
                right: &right,
                start: start,
                length: length,
                sampleRate: sampleRate,
                startFrequency: frequency,
                endFrequency: 260,
                gain: 0.05,
                pan: pan
            )
            start += Int(sampleRate * (0.18 + Double(events.nextUnit()) * 0.62))
        }
    }

    private static func renderForest(left: inout [Float], right: inout [Float], sampleRate: Double) {
        var leftNoise = Noise(seed: 0xF012E57)
        var rightNoise = Noise(seed: 0xF012E58)
        var leftBrown: Float = 0
        var rightBrown: Float = 0
        var leftAir = OnePoleHighPass(cutoff: 900, sampleRate: sampleRate)
        var rightAir = OnePoleHighPass(cutoff: 940, sampleRate: sampleRate)

        for index in left.indices {
            let whiteL = leftNoise.nextSigned()
            let whiteR = rightNoise.nextSigned()
            leftBrown = (leftBrown + 0.014 * whiteL) / 1.014
            rightBrown = (rightBrown + 0.014 * whiteR) / 1.014
            left[index] = leftBrown * 0.58 + leftAir.process(whiteL) * 0.04
            right[index] = rightBrown * 0.58 + rightAir.process(whiteR) * 0.04
        }

        var events = Noise(seed: 0xB1AD)
        var groupStart = Int(sampleRate * (0.9 + Double(events.nextUnit()) * 1.2))
        while groupStart < left.count {
            let noteCount = 2 + Int(events.nextUnit() * 3)
            let base = 1_500 + Double(events.nextUnit()) * 650
            let pan = events.nextSigned() * 0.7
            for note in 0..<noteCount {
                let start = groupStart + Int(Double(note) * sampleRate * 0.13)
                guard start < left.count else { break }
                addBirdNote(
                    left: &left,
                    right: &right,
                    start: start,
                    length: min(Int(sampleRate * 0.16), left.count - start),
                    sampleRate: sampleRate,
                    baseFrequency: base * (0.92 + Double(events.nextUnit()) * 0.1),
                    gain: 0.085,
                    pan: pan
                )
            }
            groupStart += Int(sampleRate * (2.8 + Double(events.nextUnit()) * 5.2))
        }
    }

    private static func renderFireplace(left: inout [Float], right: inout [Float], sampleRate: Double) {
        var leftNoise = Noise(seed: 0xF1AE)
        var rightNoise = Noise(seed: 0xF1AF)
        var leftBrown: Float = 0
        var rightBrown: Float = 0
        var leftAir = OnePoleHighPass(cutoff: 700, sampleRate: sampleRate)
        var rightAir = OnePoleHighPass(cutoff: 760, sampleRate: sampleRate)

        for index in left.indices {
            let whiteL = leftNoise.nextSigned()
            let whiteR = rightNoise.nextSigned()
            leftBrown = (leftBrown + 0.02 * whiteL) / 1.02
            rightBrown = (rightBrown + 0.02 * whiteR) / 1.02
            left[index] = leftBrown * 0.78 + leftAir.process(whiteL) * 0.045
            right[index] = rightBrown * 0.78 + rightAir.process(whiteR) * 0.045
        }

        var events = Noise(seed: 0xC8AC)
        var start = Int(sampleRate * 0.18)
        while start < left.count {
            let eventDuration = 0.025 + Double(events.nextUnit()) * 0.055
            let length = min(Int(sampleRate * eventDuration), left.count - start)
            let gain = 0.12 + events.nextUnit() * 0.16
            let pan = events.nextSigned() * 0.55
            for offset in 0..<length {
                let envelope = 1 - Float(offset) / Float(max(1, length))
                let sample = events.nextSigned() * envelope * gain
                left[start + offset] += sample * (1 - pan) * 0.5
                right[start + offset] += sample * (1 + pan) * 0.5
            }
            start += Int(sampleRate * (0.09 + Double(events.nextUnit()) * 0.52))
        }
    }

    private static func addChirp(
        left: inout [Float],
        right: inout [Float],
        start: Int,
        length: Int,
        sampleRate: Double,
        startFrequency: Double,
        endFrequency: Double,
        gain: Float,
        pan: Float
    ) {
        var phase = 0.0
        for offset in 0..<length {
            let progress = Double(offset) / Double(max(1, length - 1))
            let frequency = startFrequency + (endFrequency - startFrequency) * progress
            phase += 2 * Double.pi * frequency / sampleRate
            let envelope = sin(Float.pi * Float(progress))
            let sample = sin(phase) * Double(envelope * gain)
            left[start + offset] += Float(sample) * (1 - pan) * 0.5
            right[start + offset] += Float(sample) * (1 + pan) * 0.5
        }
    }

    private static func addBirdNote(
        left: inout [Float],
        right: inout [Float],
        start: Int,
        length: Int,
        sampleRate: Double,
        baseFrequency: Double,
        gain: Float,
        pan: Float
    ) {
        var phase = 0.0
        for offset in 0..<length {
            let progress = Double(offset) / Double(max(1, length - 1))
            let curve = progress < 0.4
                ? 1 + 0.55 * (progress / 0.4)
                : 1.55 - 0.47 * ((progress - 0.4) / 0.6)
            phase += 2 * Double.pi * baseFrequency * curve / sampleRate
            let envelope = pow(sin(Float.pi * Float(progress)), 1.5)
            let sample = sin(phase) * Double(envelope * gain)
            left[start + offset] += Float(sample) * (1 - pan) * 0.5
            right[start + offset] += Float(sample) * (1 + pan) * 0.5
        }
    }

    private static func softLimit(_ value: Float) -> Float {
        tanhf(value * 1.25) / tanhf(1.25)
    }
}

private struct Noise {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func nextUnit() -> Float {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        let value = state &* 0x2545F4914F6CDD1D
        return Float(value >> 40) / Float(1 << 24)
    }

    mutating func nextSigned() -> Float {
        nextUnit() * 2 - 1
    }
}

private struct OnePoleLowPass {
    private let alpha: Float
    private var previous: Float = 0

    init(cutoff: Double, sampleRate: Double) {
        alpha = Float(1 - exp(-2 * Double.pi * cutoff / sampleRate))
    }

    mutating func process(_ sample: Float) -> Float {
        previous += alpha * (sample - previous)
        return previous
    }
}

private struct OnePoleHighPass {
    private let alpha: Float
    private var previousInput: Float = 0
    private var previousOutput: Float = 0

    init(cutoff: Double, sampleRate: Double) {
        let dt = 1 / sampleRate
        let rc = 1 / (2 * Double.pi * cutoff)
        alpha = Float(rc / (rc + dt))
    }

    mutating func process(_ sample: Float) -> Float {
        let output = alpha * (previousOutput + sample - previousInput)
        previousInput = sample
        previousOutput = output
        return output
    }
}
