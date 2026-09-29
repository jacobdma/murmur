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
