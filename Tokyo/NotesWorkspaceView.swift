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

    private var vaultNotes: [Note] {
        notes.filter { $0.vault?.id == vault.id }
    }

    private var vaultFolders: [NoteFolder] {
        folders.filter { $0.vault?.id == vault.id }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedNote) {
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
                    VStack(spacing: 1) {
                        Text(vault.name)
                            .font(.headline)
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
            if let selectedNote {
                NoteDetailView(note: selectedNote)
            } else {
                ContentUnavailableView("Select a Note", systemImage: "note.text", description: Text("Choose a note from the sidebar or create a new one."))
            }
        }
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
