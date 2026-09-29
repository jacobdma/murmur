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
    var duration: TimeInterval?
    init(audio: String? = nil, duration: TimeInterval? = nil) { self.audio = audio; self.duration = duration }
    var url: URL? { audio.map { URL.documentsDirectory.appending(path: $0) } }
    var title: String { [text, transcript ?? ""].first { !$0.isEmpty } ?? "Voice Memo" }
    var subtitle: String {
        let date = created.formatted(date: .abbreviated, time: .shortened)
        return duration.map { "\(date) · \(format($0))" } ?? date
    }
}

extension Color {
    static let murmur = Color(red: 0.98, green: 0.56, blue: 0.3)
}

func format(_ t: TimeInterval) -> String {
    Duration.seconds(t).formatted(.time(pattern: .minuteSecond))
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.created, order: .reverse) private var notes: [Note]
    @State private var path: [Note] = []
    @State private var recorder: AVAudioRecorder?
    @State private var levels = [Float](repeating: 0, count: 40)

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(notes) { note in
                        NavigationLink(value: note) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title).font(.headline).lineLimit(1)
                                Text(note.subtitle).font(.subheadline).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGray6))
            .navigationTitle("Memos")
            .navigationDestination(for: Note.self) { NoteView(note: $0) }
            .safeAreaInset(edge: .bottom) { recordBar.padding(.horizontal) }
        }
        .tint(.murmur)
        .task { await activateAudioSession() }
        .task(id: recorder == nil) {
            while let recorder, !Task.isCancelled {
                recorder.updateMeters()
                levels = levels.dropFirst() + [max(0, (recorder.averagePower(forChannel: 0) + 50) / 50)]
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    var recordBar: some View {
        ZStack {
            if let recorder {
                HStack(spacing: 16) {
                    HStack(spacing: 3) {
                        ForEach(levels.indices, id: \.self) { i in
                            Capsule().frame(width: 3, height: 4 + 28 * CGFloat(levels[i]))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Text(format(recorder.currentTime)).font(.headline).monospacedDigit()
                    Button("Stop", systemImage: "stop.fill") { Task { await toggleRecording() } }
                        .labelStyle(.iconOnly).font(.title3)
                        .foregroundStyle(Color.murmur)
                        .frame(width: 44, height: 44)
                        .background(.white, in: .circle)
                }
                .padding(10).padding(.leading, 12)
                .transition(.opacity.animation(.easeIn(duration: 0.12).delay(0.05)))
            } else {
                Button { Task { await toggleRecording() } } label: {
                    Image(systemName: "plus").font(.title.bold())
                        .frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(.rect)
                }
                .accessibilityLabel("Record")
                .transition(.opacity.animation(.easeOut(duration: 0.1)))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: recorder == nil ? 64 : .infinity).frame(height: 64)
        .background(Color.murmur, in: .rect(cornerRadius: recorder == nil ? 20 : 32))
        .clipShape(.rect(cornerRadius: recorder == nil ? 20 : 32))
        .frame(maxWidth: .infinity, alignment: .trailing)
        .animation(.spring(duration: 0.3, bounce: 0.15), value: recorder == nil)
    }

    func toggleRecording() async {
        if let recorder {
            let duration = recorder.currentTime
            recorder.stop()
            self.recorder = nil
            let note = Note(audio: recorder.url.lastPathComponent, duration: duration)
            context.insert(note)
            path.append(note)
            note.transcript = await transcribe(recorder.url) ?? "No transcript"
        } else if await AVAudioApplication.requestRecordPermission() {
            let url = URL.documentsDirectory.appending(path: "\(UUID()).m4a")
            recorder = try? AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 1])
            levels = levels.map { _ in 0 }
            recorder?.isMeteringEnabled = true
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
            TextEditor(text: $note.text).scrollContentBackground(.hidden)
        }
        .padding(.horizontal)
        .background(Color(.systemGray6))
        .task { player = note.url.flatMap { try? AVAudioPlayer(contentsOf: $0) } }
    }
}
