//
//  Note.swift
//  murmur
//
//  Created by Jacob Ma on 9/29/26.
//

import SwiftUI
import SwiftData

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
