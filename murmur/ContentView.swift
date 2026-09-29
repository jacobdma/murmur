//
//  ContentView.swift
//  murmur
//
//  Created by Jacob Ma on 9/28/26.
//

import SwiftUI
import SwiftData
import AVFoundation
import Speech

@Model final class Note {
    var text = ""
    var created = Date.now
    var audio: String?
    var transcript: String?
    init(audio: String? = nil) { self.audio = audio }
    var url: URL? { audio.map { URL.documentsDirectory.appending(path: $0) } }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.created, order: .reverse) private var notes: [Note]
    @State private var path: [Note] = []
    @State private var recorder: AVAudioRecorder?

    var body: some View {
        NavigationStack(path: $path) {
            List(notes) { note in
                NavigationLink([note.text, note.transcript ?? ""].first { !$0.isEmpty } ?? "Voice Memo", value: note)
                    .lineLimit(1)
            }
            .navigationTitle("Memos")
            .navigationDestination(for: Note.self) { NoteView(note: $0) }
            .toolbar {
                Button("Record", systemImage: recorder == nil ? "plus" : "stop.circle.fill") {
                    Task { await toggleRecording() }
                }
                .tint(recorder == nil ? nil : .red)
            }
        }
        .task { await activateAudioSession() }
    }

    func toggleRecording() async {
        if let recorder {
            recorder.stop()
            self.recorder = nil
            let note = Note(audio: recorder.url.lastPathComponent)
            context.insert(note)
            path.append(note)
            note.transcript = await transcribe(recorder.url) ?? "No transcript"
        } else if await AVAudioApplication.requestRecordPermission() {
            let url = URL.documentsDirectory.appending(path: "\(UUID()).m4a")
            recorder = try? AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 1])
            recorder?.record()
        }
    }
}

@concurrent nonisolated func activateAudioSession() async {
    try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: .defaultToSpeaker)
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

struct NoteView: View {
    @Bindable var note: Note
    @State private var player: AVAudioPlayer?

    var body: some View {
        VStack {
            if let player {
                VStack(alignment: .leading) {
                    TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                        HStack {
                            Button(player.isPlaying ? "Pause" : "Play", systemImage: player.isPlaying ? "pause.circle.fill" : "play.circle.fill") {
                                if player.isPlaying { player.pause() } else { player.play() }
                            }
                            .labelStyle(.iconOnly).font(.title)
                            Slider(value: Binding(get: { player.currentTime }, set: { player.currentTime = $0 }), in: 0...player.duration)
                            Text("\(format(player.currentTime)) / \(format(player.duration))")
                                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    Text(note.transcript ?? "Transcribing…").foregroundStyle(.secondary)
                }
                .padding()
                .background(.fill.tertiary, in: .rect(cornerRadius: 16))
            }
            TextEditor(text: $note.text)
        }
        .padding(.horizontal)
        .task { player = note.url.flatMap { try? AVAudioPlayer(contentsOf: $0) } }
    }

    func format(_ t: TimeInterval) -> String {
        Duration.seconds(t).formatted(.time(pattern: .minuteSecond))
    }
}
