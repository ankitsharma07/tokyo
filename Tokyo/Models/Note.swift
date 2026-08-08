//
//  Note.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import Foundation
import SwiftData

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
