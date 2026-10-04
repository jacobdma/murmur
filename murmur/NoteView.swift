//
//  NoteView.swift
//  murmur
//
//  Created by Jacob Ma on 9/29/26.
//

import SwiftUI
import SwiftData
import AVFoundation

struct NoteView: View {
    @Bindable var note: Note
    @State private var player: AVAudioPlayer?
    @State private var editing = false
    @FocusState private var focused: Bool

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
            if editing {
                TextEditor(text: $note.text).scrollContentBackground(.hidden).focused($focused).onAppear { focused = true }
            } else {
                ScrollView { FormattedText(text: note.text).padding(.vertical) }
            }
        }
        .padding(.horizontal)
        .background(Color(.systemGray6))
        .toolbar {
            if editing {
                Button(role: .confirm) { editing = false }
            } else {
                Button("Edit") { editing = true }
            }
        }
        .task { player = note.url.flatMap { try? AVAudioPlayer(contentsOf: $0) } }
    }
}

struct FormattedText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, line in
                switch NoteLine(line) {
                case .heading(let level, let content):
                    Text(content).font([Font.title, .title2, .title3][level - 1].bold())
                        .accessibilityAddTraits(.isHeader)
                case .bullet(let content):
                    HStack(alignment: .firstTextBaseline) {
                        Text("•")
                        Text(content)
                    }
                    .accessibilityElement(children: .combine)
                case .text(let content):
                    Text(content)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }
}
