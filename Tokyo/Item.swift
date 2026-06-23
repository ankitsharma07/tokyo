//
//  Item.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import Foundation
import SwiftData

enum NoteMarkupFormat: String, Codable, CaseIterable, Identifiable {
    case markdown
    case org

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .markdown:
            "Markdown"
        case .org:
            "Org"
        }
    }
}

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

@Model
final class NoteFolder {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var vault: Vault?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        vault: Vault? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.vault = vault
    }
}

@Model
final class Note {
    var id: UUID
    var title: String
    var body: String
    var markupFormatRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var vault: Vault?

    var markupFormat: NoteMarkupFormat {
        get { NoteMarkupFormat(rawValue: markupFormatRawValue) ?? .markdown }
        set { markupFormatRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        body: String = "",
        markupFormat: NoteMarkupFormat = .markdown,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        vault: Vault? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.markupFormatRawValue = markupFormat.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.vault = vault
    }
}
