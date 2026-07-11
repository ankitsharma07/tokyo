//
//  NotesWorkspaceView.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import SwiftUI
import SwiftData

struct NotesWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var vault: Vault
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Query(sort: \NoteFolder.createdAt) private var folders: [NoteFolder]
    @State private var selectedNote: Note?
    @State private var isShowingGraph = false
    @State private var noteGraph = NoteGraph.empty
    @State private var graphErrorMessage: String?

    private var vaultNotes: [Note] {
        notes.filter { $0.vault?.id == vault.id }
    }

    private var vaultFolders: [NoteFolder] {
        folders.filter { $0.vault?.id == vault.id }
    }

    private var graphIndexKey: String {
        vaultNotes
            .map { "\($0.id.uuidString)|\($0.title)|\($0.body)|\($0.updatedAt.timeIntervalSinceReferenceDate)" }
            .joined(separator: "\n")
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedNote) {
                Section {
                    Button {
                        isShowingGraph = true
                    } label: {
                        Label("Graph", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                }

                if !vaultFolders.isEmpty {
                    Section("Folders") {
                        ForEach(vaultFolders) { folder in
                            Label(folder.name, systemImage: "folder")
                                .lineLimit(1)
                        }
                    }
                }

                Section("Notes") {
                    if vaultNotes.isEmpty {
                        ContentUnavailableView("No Notes", systemImage: "doc.text", description: Text("Use the plus button to create your first note."))
                    } else {
                        ForEach(vaultNotes) { note in
                            NavigationLink(value: note) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title)
                                        .lineLimit(1)
                                    Text(note.updatedAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteNotes)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 280)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 4) {
                        Text(vault.name)
                            .font(.headline)
                            .lineLimit(1)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 7)
                            .background(.quaternary.opacity(0.6), in: Capsule())
                            .fixedSize(horizontal: true, vertical: false)
                        if let description = vault.vaultDescription, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                ToolbarItem {
                    Menu {
                        Button(action: createNote) {
                            Label("Create New Note", systemImage: "square.and.pencil")
                        }

                        Button(action: createFolder) {
                            Label("Create New Folder", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Label("Create", systemImage: "plus")
                    }
                }

                ToolbarItem {
                    Button {
                        isShowingGraph = true
                    } label: {
                        Label("Graph", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                }

                ToolbarItem {
                    Menu {
                        Picker("New Note Format", selection: Binding(
                            get: { vault.defaultNoteFormat },
                            set: { format in
                                vault.defaultNoteFormat = format
                                vault.updatedAt = Date()
                            }
                        )) {
                            ForEach(NoteMarkupFormat.allCases) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
        } detail: {
            VStack(spacing: 0) {
                if let graphErrorMessage {
                    Label(graphErrorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.orange.opacity(0.12))
                }

                if isShowingGraph {
                    NoteGraphView(graph: noteGraph, selectedNoteID: selectedNote?.id) { noteID in
                        selectNote(withID: noteID)
                    }
                } else if let selectedNote {
                    NoteDetailView(note: selectedNote)
                } else {
                    ContentUnavailableView("Select a Note", systemImage: "note.text", description: Text("Choose a note from the sidebar or create a new one."))
                }
            }
        }
        .task {
            refreshGraphIndex()
        }
        .onChange(of: graphIndexKey) { _, _ in
            refreshGraphIndex()
        }
        .onChange(of: selectedNote?.id) { _, newValue in
            if newValue != nil {
                isShowingGraph = false
            }
        }
    }

    private func refreshGraphIndex() {
        switch NoteGraphStore.shared {
        case .success(let store):
            do {
                try store.rebuildIndex(for: vaultNotes, vaultID: vault.id)
                noteGraph = try store.graph(for: vault.id)
                graphErrorMessage = nil
            } catch {
                graphErrorMessage = error.localizedDescription
            }
        case .failure(let error):
            graphErrorMessage = error.localizedDescription
        }
    }

    private func selectNote(withID noteID: UUID) {
        guard let note = vaultNotes.first(where: { $0.id == noteID }) else { return }
        selectedNote = note
        isShowingGraph = false
    }

    private func createNote() {
        let now = Date()
        let note = Note(title: "Untitled Note", markupFormat: vault.defaultNoteFormat, createdAt: now, updatedAt: now, vault: vault)
        modelContext.insert(note)
        selectedNote = note
        vault.updatedAt = now
    }

    private func createFolder() {
        let now = Date()
        let folder = NoteFolder(name: "New Folder", createdAt: now, updatedAt: now, vault: vault)
        modelContext.insert(folder)
        vault.updatedAt = now
    }

    private func deleteNotes(offsets: IndexSet) {
        for index in offsets {
            let note = vaultNotes[index]
            if selectedNote?.id == note.id {
                selectedNote = nil
            }
            modelContext.delete(note)
        }
        vault.updatedAt = Date()
    }
}
