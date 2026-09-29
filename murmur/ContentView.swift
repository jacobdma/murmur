//
//  ContentView.swift
//  murmur
//
//  Created by Jacob Ma on 9/28/26.
//

import SwiftUI
import SwiftData
import AVFoundation

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Note> { $0.deleted == nil }, sort: \Note.created, order: .reverse) private var notes: [Note]
    @State private var path: [Note] = []
    @State private var recorder: AVAudioRecorder?
    @State private var levels = [Float](repeating: 0, count: 40)

    var body: some View {
        NavigationStack(path: $path) {
            List(notes) { note in
                NavigationLink(value: note) { NoteRow(note: note) }
                    .navigationLinkIndicatorVisibility(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) { note.deleted = .now }.tint(.red)
                    }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGray6))
            .navigationTitle("Memos")
            .navigationDestination(for: Note.self) { NoteView(note: $0) }
            .toolbar {
                NavigationLink { DeletedView() } label: { Label("Recently Deleted", systemImage: "trash") }
            }
            .safeAreaInset(edge: .bottom) { recordBar.padding(.horizontal) }
        }
        .tint(.murmur)
        .task {
            await activateAudioSession()
            let trash = (try? context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.deleted != nil }))) ?? []
            for note in trash where note.daysLeft <= 0 { note.purge(from: context) }
        }
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

struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title).font(.headline).lineLimit(1)
            Text(note.subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}
