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
