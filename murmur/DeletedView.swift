//
//  DeletedView.swift
//  murmur
//
//  Created by Jacob Ma on 9/29/26.
//

import SwiftUI
import SwiftData

struct DeletedView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Note> { $0.deleted != nil }, sort: \Note.deleted, order: .reverse) private var notes: [Note]

    var body: some View {
        List(notes) { note in
            NoteRow(note: note)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(allowsFullSwipe: false) {
                    Button("Delete", systemImage: "trash", role: .destructive) { note.purge(from: context) }.tint(.red)
                    Button("Restore", systemImage: "arrow.uturn.backward") { note.deleted = nil }.tint(.blue)
                }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGray6))
        .navigationTitle("Recently Deleted")
    }
}
