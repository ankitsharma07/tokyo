//
//  NoteFolder.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import Foundation
import SwiftData

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
