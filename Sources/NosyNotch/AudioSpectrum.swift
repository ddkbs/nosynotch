import Accelerate
import AppKit
import CoreAudio
import os

/// Live loudness per frequency band of what Spotify / Music is playing, for the "live" equalizer.
///
/// Uses a Core Audio process tap (macOS 14.2+): a private, unmuted tap on the player's audio processes inside
/// a private aggregate device. The first time, macOS asks for "System Audio Recording" permission
/// (`NSAudioCaptureUsageDescription`). Without it the tap delivers silence and the view falls back to the
/// built-in animation.
final class AudioSpectrum: @unchecked Sendable {
    static let bandCount = 5

    private let lock = OSAllocatedUnfairLock(initialState: State())
    private let queue = DispatchQueue(label: "dev.davidkubus.nosynotch.audio", qos: .userInteractive)
    private let log = Logger(subsystem: "dev.davidkubus.nosynotch", category: "audio")

    private struct State {
        var levels = [Float](repeating: 0, count: AudioSpectrum.bandCount)
        var lastSignal = Date.distantPast
    }

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private var bundlePrefix: String?

    // FFT
    private static let fftSize = 1024
    private let fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(AudioSpectrum.fftSize), .FORWARD)
    private var window = [Float](repeating: 0, count: AudioSpectrum.fftSize)
    private var ring = [Float](repeating: 0, count: AudioSpectrum.fftSize)
    private var ringIndex = 0
    private var sampleRate: Float = 48_000
    private var bandPeak = [Float](repeating: -60, count: AudioSpectrum.bandCount)
    private var smoothed = [Float](repeating: 0, count: AudioSpectrum.bandCount)

    init() {
        vDSP_hann_window(&window, vDSP_Length(Self.fftSize), Int32(vDSP_HANN_NORM))
    }

    deinit {
        stopTap()
        if let fftSetup { vDSP_DFT_DestroySetup(fftSetup) }
    }

    /// Current band levels (0…1), or nil if nothing audible arrived recently (no permission, paused …).
    var levels: [Float]? {
        lock.withLock { state in
            Date().timeIntervalSince(state.lastSignal) < 0.6 ? state.levels : nil
        }
    }

    /// Start tapping the given player (e.g. "com.spotify.client"), or stop with nil.
    func follow(bundleID: String?) {
        queue.async { [self] in
            guard bundleID != bundlePrefix else { return }
            stopTap()
            bundlePrefix = bundleID
            guard let bundleID else { return }
            if #available(macOS 14.2, *) {
                do { try startTap(bundleID: bundleID) } catch {
                    log.error("audio tap failed: \(error.localizedDescription, privacy: .public)")
                    stopTap()
                }
            }
        }
    }

    // MARK: - Tap

    @available(macOS 14.2, *)
    private func startTap(bundleID: String) throws {
        let processes = Self.audioProcesses(matching: bundleID)
        guard !processes.isEmpty else { throw Self.error("No audio process for \(bundleID)") }

        let description = CATapDescription(stereoMixdownOfProcesses: processes)
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = .unmuted
        try check(AudioHardwareCreateProcessTap(description, &tapID), "create tap")

        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        try check(AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format), "tap format")
        sampleRate = Float(format.mSampleRate)
        let interleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
        let channels = Int(max(1, format.mChannelsPerFrame))

        let outputUID = try Self.defaultOutputUID()
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Nosy Notch Equalizer",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString,
            ]],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "aggregate device")

        try check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { [weak self] _, input, _, _, _ in
            self?.consume(input, interleaved: interleaved, channels: channels)
        }, "io proc")
        try check(AudioDeviceStart(aggregateID, procID), "start")
        log.info("audio tap running for \(bundleID, privacy: .public)")
    }

    private func stopTap() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown, #available(macOS 14.2, *) {
            AudioHardwareDestroyProcessTap(tapID)
        }
        procID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
        lock.withLock { $0 = State() }
    }

    // MARK: - Analysis

    private func consume(_ input: UnsafePointer<AudioBufferList>, interleaved: Bool, channels: Int) {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        guard let first = buffers.first, let data = first.mData else { return }
        let samples = data.assumingMemoryBound(to: Float.self)
        let stride = interleaved ? channels : 1
        let frames = Int(first.mDataByteSize) / MemoryLayout<Float>.size / stride

        for i in 0..<frames {
            ring[ringIndex] = samples[i * stride]
            ringIndex = (ringIndex + 1) % Self.fftSize
            if ringIndex % (Self.fftSize / 2) == 0 { analyze() }
        }
    }

    private func analyze() {
        guard let fftSetup else { return }
        let n = Self.fftSize
        // Oldest sample first, windowed.
        var frame = [Float](repeating: 0, count: n)
        for i in 0..<n { frame[i] = ring[(ringIndex + i) % n] * window[i] }

        var peak: Float = 0
        vDSP_maxmgv(frame, 1, &peak, vDSP_Length(n))

        var realIn = frame
        var imagIn = [Float](repeating: 0, count: n)
        var realOut = [Float](repeating: 0, count: n)
        var imagOut = [Float](repeating: 0, count: n)
        vDSP_DFT_Execute(fftSetup, &realIn, &imagIn, &realOut, &imagOut)

        var magnitudes = [Float](repeating: 0, count: n / 2)
        realOut.withUnsafeMutableBufferPointer { re in
            imagOut.withUnsafeMutableBufferPointer { im in
                var complex = DSPSplitComplex(realp: re.baseAddress!, imagp: im.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(n / 2))
            }
        }

        // Log-spaced bands: bass … treble.
        let edges: [Float] = [40, 150, 400, 1_200, 3_500, 10_000]
        let binWidth = sampleRate / Float(n)
        var bands = [Float](repeating: 0, count: Self.bandCount)
        for b in 0..<Self.bandCount {
            let lo = max(1, Int(edges[b] / binWidth))
            let hi = max(lo + 1, min(n / 2, Int(edges[b + 1] / binWidth)))
            var mean: Float = 0
            magnitudes[lo..<hi].withUnsafeBufferPointer { vDSP_meanv($0.baseAddress!, 1, &mean, vDSP_Length(hi - lo)) }
            // Automatic gain per band: compare to that band's recent peak (which slowly sinks), so quiet songs
            // and loud masters both use the full height and the bars actually jump.
            let db = 20 * log10(max(mean / Float(n), 1e-9))
            bandPeak[b] = max(db, bandPeak[b] - 0.12)
            let range: Float = 22
            let x = min(1, max(0, (db - (bandPeak[b] - range)) / range))
            bands[b] = pow(x, 1.6)
        }

        // Fast attack, slow release – looks like a real VU meter.
        for b in 0..<Self.bandCount {
            let target = bands[b]
            smoothed[b] += (target - smoothed[b]) * (target > smoothed[b] ? 0.75 : 0.25)
        }
        let audible = peak > 0.0005
        let snapshot = smoothed
        lock.withLock { state in
            state.levels = snapshot
            if audible { state.lastSignal = Date() }
        }
    }

    // MARK: - Core Audio helpers

    /// Audio process objects whose bundle id starts with `bundleID` (Spotify plays through helper processes).
    private static func audioProcesses(matching bundleID: String) -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr
        else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr
        else { return [] }

        return ids.filter { id in
            var address = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyBundleID,
                                                     mScope: kAudioObjectPropertyScopeGlobal,
                                                     mElement: kAudioObjectPropertyElementMain)
            var value: Unmanaged<CFString>?
            var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr,
                  let bundle = value?.takeRetainedValue() as String? else { return false }
            return bundle.hasPrefix(bundleID)
        }
    }

    private static func defaultOutputUID() throws -> String {
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr
        else { throw error("No output device") }

        address.mSelector = kAudioDevicePropertyDeviceUID
        var uid: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &uid) == noErr,
              let value = uid?.takeRetainedValue() as String? else { throw error("No output device UID") }
        return value
    }

    private func check(_ status: OSStatus, _ what: String) throws {
        guard status == noErr else { throw Self.error("\(what) failed (\(status))") }
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "NosyNotch.Audio", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
