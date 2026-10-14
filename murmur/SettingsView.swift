//
//  SettingsView.swift
//  murmur
//
//  Created by Jacob Ma on 9/29/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("voiceIsolation") private var voiceIsolation = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Voice Isolation", isOn: $voiceIsolation)
                } footer: {
                    Text("Reduces background noise while recording. Turn off to capture music or ambient sound.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(role: .confirm) { dismiss() } }
        }
        .tint(.murmur)
        .presentationDetents([.medium])
    }
}
