//
//  murmurApp.swift
//  murmur
//
//  Created by Jacob Ma on 9/28/26.
//

import SwiftUI
import SwiftData

@main
struct murmurApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Note.self)
    }
}
