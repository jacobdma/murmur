//
//  Audio.swift
//  murmur
//
//  Created by Jacob Ma on 9/29/26.
//

import AVFoundation
import Speech

@concurrent nonisolated func activateAudioSession() async {
    try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowAirPlay])
    try? AVAudioSession.sharedInstance().setActive(true)
}

nonisolated final class Recorder: @unchecked Sendable {
    let url = URL.documentsDirectory.appending(path: "\(UUID()).m4a")
    private(set) var power: Float = -160
    private let engine = AVAudioEngine()
    private let file: AVAudioFile
    private let started = Date.now
    var currentTime: TimeInterval { Date.now.timeIntervalSince(started) }

    init(isolateVoice: Bool) throws {
        let input = engine.inputNode
        try input.setVoiceProcessingEnabled(isolateVoice)
        let format = input.outputFormat(forBus: 0)
        file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128_000,
        ])
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
            try? file.write(from: buffer)
            let n = Int(buffer.frameLength)
            let meanSquare = (0..<n).reduce(Float(0)) { $0 + samples[$1] * samples[$1] } / Float(n)
            power = 10 * log10(max(meanSquare, 1e-12))
        }
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file.close()
    }
}

nonisolated func transcribe(_ url: URL) async -> String? {
    guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current) else { return nil }
    let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
    do {
        if let download = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await download.downloadAndInstall()
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        async let text = transcriber.results.reduce(into: "") { $0 += String($1.text.characters) }
        if let end = try await analyzer.analyzeSequence(from: AVAudioFile(forReading: url)) {
            try await analyzer.finalizeAndFinish(through: end)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        let transcript = try await text.trimmingCharacters(in: .whitespacesAndNewlines)
        return transcript.isEmpty ? nil : transcript
    } catch {
        return nil
    }
}
