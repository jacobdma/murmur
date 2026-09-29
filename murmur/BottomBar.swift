//
//  BottomBar.swift
//  murmur
//
//  Created by Jacob Ma on 9/29/26.
//

import SwiftUI
import AVFoundation

struct BottomBar: View {
    @Binding var query: String
    let recorder: AVAudioRecorder?
    let toggleRecording: () -> Void
    @State private var levels = [Float](repeating: 0, count: 40)
    @FocusState private var searching: Bool

    var body: some View {
        HStack(spacing: 12) {
            if recorder == nil { searchField.transition(.opacity) }
            recordBar
        }
        .padding(.horizontal)
        .padding(.bottom, searching ? 12 : 0)
        .animation(.spring(duration: 0.3, bounce: 0.15), value: recorder == nil)
        .task(id: recorder == nil) {
            guard let recorder else { return }
            levels = levels.map { _ in 0 }
            while !Task.isCancelled {
                recorder.updateMeters()
                levels = levels.dropFirst() + [max(0, (recorder.averagePower(forChannel: 0) + 50) / 50)]
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(Color(.placeholderText))
            TextField("Search", text: $query).submitLabel(.search).focused($searching).autocorrectionDisabled()
        }
        .font(.title3)
        .padding(.horizontal, 20)
        .frame(height: 64)
        .glassEffect(in: .capsule)
    }

    var recordBar: some View {
        let radius: CGFloat = recorder == nil ? 20 : 32
        return ZStack {
            if let recorder {
                HStack(spacing: 16) {
                    HStack(spacing: 3) {
                        ForEach(levels.indices, id: \.self) { i in
                            Capsule().frame(width: 3, height: 4 + 28 * CGFloat(levels[i]))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Text(format(recorder.currentTime)).font(.headline).monospacedDigit()
                    Button("Stop", systemImage: "stop.fill", action: toggleRecording)
                        .labelStyle(.iconOnly).font(.title3)
                        .foregroundStyle(Color.murmur)
                        .frame(width: 44, height: 44)
                        .background(.white, in: .circle)
                }
                .padding(10).padding(.leading, 12)
                .transition(.opacity.animation(.easeIn(duration: 0.12).delay(0.05)))
            } else {
                Button(action: toggleRecording) {
                    Image(systemName: "plus").font(.title.bold())
                        .frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(.rect)
                }
                .accessibilityLabel("Record")
                .transition(.opacity.animation(.easeOut(duration: 0.1)))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: recorder == nil ? 64 : .infinity).frame(height: 64)
        .background(Color.murmur)
        .clipShape(.rect(cornerRadius: radius))
    }
}
