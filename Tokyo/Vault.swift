//
//  Vault.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import Foundation
import SwiftData

@Model
final class Vault {
    var id: UUID
    var name: String
    var vaultDescription: String?
    var defaultNoteFormatRawValue: String?
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Note.vault) var notes: [Note]?
    @Relationship(deleteRule: .cascade, inverse: \NoteFolder.vault) var folders: [NoteFolder]?

    var defaultNoteFormat: NoteMarkupFormat {
        get {
            guard let defaultNoteFormatRawValue else { return .markdown }
            return NoteMarkupFormat(rawValue: defaultNoteFormatRawValue) ?? .markdown
        }
        set { defaultNoteFormatRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        vaultDescription: String? = nil,
        defaultNoteFormat: NoteMarkupFormat = .markdown,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        notes: [Note]? = [],
        folders: [NoteFolder]? = []
    ) {
        self.id = id
        self.name = name
        self.vaultDescription = vaultDescription
        self.defaultNoteFormatRawValue = defaultNoteFormat.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.notes = notes
        self.folders = folders
    }
}
