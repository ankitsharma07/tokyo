//
//  NoteDetailView.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Bindable var note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Title", text: $note.title)
                .font(.largeTitle.bold())
                .textFieldStyle(.plain)

            Text(note.markupFormat.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            NoteBodyEditor(note: note)
        }
        .padding(28)
        .onChange(of: note.title) { _, _ in
            note.updatedAt = Date()
        }
        .onChange(of: note.body) { _, _ in
            note.updatedAt = Date()
        }
    }
}
