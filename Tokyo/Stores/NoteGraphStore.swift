//
//  NoteGraphStore.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct NoteGraph: Equatable {
    var nodes: [NoteGraphNode]
    var edges: [NoteGraphEdge]

    static let empty = NoteGraph(nodes: [], edges: [])
}

struct NoteGraphNode: Identifiable, Equatable {
    let id: UUID
    let title: String
}

struct NoteGraphEdge: Identifiable, Equatable {
    let sourceID: UUID
    let targetID: UUID

    var id: String {
        "\(sourceID.uuidString)->\(targetID.uuidString)"
    }
}

enum NoteGraphStoreError: LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case executeFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message), .prepareFailed(let message), .executeFailed(let message):
            message
        }
    }
}

final class NoteGraphStore {
    static let shared = Result { try NoteGraphStore() }

    private var database: OpaquePointer?

    private init() throws {
        let databaseURL = try Self.databaseURL()
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        guard sqlite3_open_v2(databaseURL.path, &database, flags, nil) == SQLITE_OK else {
            let message = database.map(Self.errorMessage) ?? "Could not open graph database."
            throw NoteGraphStoreError.openFailed(message)
        }

        try execute("PRAGMA foreign_keys = ON;")
        try execute("""
            CREATE TABLE IF NOT EXISTS notes (
                id TEXT PRIMARY KEY,
                vault_id TEXT NOT NULL,
                title TEXT NOT NULL
            );
            """)
        try execute("""
            CREATE TABLE IF NOT EXISTS note_links (
                source_id TEXT NOT NULL,
                target_id TEXT NOT NULL,
                PRIMARY KEY (source_id, target_id),
                FOREIGN KEY (source_id) REFERENCES notes(id) ON DELETE CASCADE,
                FOREIGN KEY (target_id) REFERENCES notes(id) ON DELETE CASCADE
            );
            """)
        try execute("CREATE INDEX IF NOT EXISTS note_links_source_index ON note_links(source_id);")
        try execute("CREATE INDEX IF NOT EXISTS note_links_target_index ON note_links(target_id);")
        try execute("CREATE INDEX IF NOT EXISTS notes_vault_index ON notes(vault_id);")
    }

    deinit {
        sqlite3_close(database)
    }

    func rebuildIndex(for notes: [Note], vaultID: UUID) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try execute("DELETE FROM notes WHERE vault_id = ?;", vaultID.uuidString)

            let noteSnapshots = notes.map { NoteGraphSnapshot(id: $0.id, title: $0.title, body: $0.body) }
            let titleLookup = Dictionary(uniqueKeysWithValues: noteSnapshots.map { ($0.normalizedTitle, $0.id) })
            let idSet = Set(noteSnapshots.map(\.id))

            for note in noteSnapshots {
                try execute(
                    "INSERT INTO notes (id, vault_id, title) VALUES (?, ?, ?);",
                    note.id.uuidString,
                    vaultID.uuidString,
                    note.title
                )
            }

            for note in noteSnapshots {
                let targetIDs = NoteLinkParser.targets(in: note.body, titleLookup: titleLookup, idSet: idSet)
                    .filter { $0 != note.id }
                for targetID in targetIDs {
                    try execute(
                        "INSERT OR IGNORE INTO note_links (source_id, target_id) VALUES (?, ?);",
                        note.id.uuidString,
                        targetID.uuidString
                    )
                }
            }

            try execute("COMMIT TRANSACTION;")
        } catch {
            try? execute("ROLLBACK TRANSACTION;")
            throw error
        }
    }

    func graph(for vaultID: UUID) throws -> NoteGraph {
        let nodes = try selectNodes(vaultID: vaultID)
        let nodeIDs = Set(nodes.map(\.id))
        let edges = try selectEdges(nodeIDs: nodeIDs)
        return NoteGraph(nodes: nodes, edges: edges)
    }

    private static func databaseURL() throws -> URL {
        let supportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appDirectory = supportDirectory.appending(path: "Tokyo", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory.appending(path: "note-graph.sqlite")
    }

    private func selectNodes(vaultID: UUID) throws -> [NoteGraphNode] {
        try select(
            sql: "SELECT id, title FROM notes WHERE vault_id = ? ORDER BY title COLLATE NOCASE;",
            bindings: [vaultID.uuidString]
        ) { statement in
            guard
                let idText = sqlite3_column_text(statement, 0),
                let titleText = sqlite3_column_text(statement, 1),
                let id = UUID(uuidString: String(cString: idText))
            else { return nil }

            return NoteGraphNode(id: id, title: String(cString: titleText))
        }
    }

    private func selectEdges(nodeIDs: Set<UUID>) throws -> [NoteGraphEdge] {
        guard !nodeIDs.isEmpty else { return [] }

        return try select(sql: "SELECT source_id, target_id FROM note_links ORDER BY source_id, target_id;") { statement in
            guard
                let sourceText = sqlite3_column_text(statement, 0),
                let targetText = sqlite3_column_text(statement, 1),
                let sourceID = UUID(uuidString: String(cString: sourceText)),
                let targetID = UUID(uuidString: String(cString: targetText)),
                nodeIDs.contains(sourceID),
                nodeIDs.contains(targetID)
            else { return nil }

            return NoteGraphEdge(sourceID: sourceID, targetID: targetID)
        }
    }

    private func execute(_ sql: String, _ bindings: String...) throws {
        try execute(sql, bindings)
    }

    private func execute(_ sql: String, _ bindings: [String] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw NoteGraphStoreError.prepareFailed(Self.errorMessage(database))
        }
        defer { sqlite3_finalize(statement) }

        for (index, binding) in bindings.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), binding, -1, sqliteTransient)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw NoteGraphStoreError.executeFailed(Self.errorMessage(database))
        }
    }

    private func select<Value>(
        sql: String,
        bindings: [String] = [],
        map: (OpaquePointer?) -> Value?
    ) throws -> [Value] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw NoteGraphStoreError.prepareFailed(Self.errorMessage(database))
        }
        defer { sqlite3_finalize(statement) }

        for (index, binding) in bindings.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), binding, -1, sqliteTransient)
        }

        var values: [Value] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let value = map(statement) {
                values.append(value)
            }
        }
        return values
    }

    nonisolated private static func errorMessage(_ database: OpaquePointer?) -> String {
        guard let error = sqlite3_errmsg(database) else { return "Unknown SQLite error." }
        return String(cString: error)
    }
}

private struct NoteGraphSnapshot {
    let id: UUID
    let title: String
    let body: String

    var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum NoteLinkParser {
    static func targets(in body: String, titleLookup: [String: UUID], idSet: Set<UUID>) -> Set<UUID> {
        var targets: Set<UUID> = []
        var searchRange = body.startIndex..<body.endIndex

        while let openingRange = body.range(of: "[[", range: searchRange) {
            let contentStart = openingRange.upperBound
            guard let closingRange = body.range(of: "]]", range: contentStart..<body.endIndex) else { break }

            let rawTarget = String(body[contentStart..<closingRange.lowerBound])
            let target = rawTarget.components(separatedBy: "|").first ?? rawTarget
            let normalizedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)

            if let id = UUID(uuidString: normalizedTarget), idSet.contains(id) {
                targets.insert(id)
            } else if let id = titleLookup[normalizedTarget.lowercased()] {
                targets.insert(id)
            }

            searchRange = closingRange.upperBound..<body.endIndex
        }

        return targets
    }
}
