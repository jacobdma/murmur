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
    guard await withCheckedContinuation({ c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) } }),
          let recognizer = SFSpeechRecognizer() else { return nil }
    return await withCheckedContinuation { c in
        recognizer.recognitionTask(with: SFSpeechURLRecognitionRequest(url: url)) { result, error in
            if error != nil { c.resume(returning: nil) }
            else if let result, result.isFinal { c.resume(returning: result.bestTranscription.formattedString) }
        }
    }
}
