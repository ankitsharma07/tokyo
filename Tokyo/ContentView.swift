//
//  ContentView.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Vault.createdAt) private var vaults: [Vault]

    var body: some View {
        if let vault = vaults.first {
            NotesWorkspaceView(vault: vault)
        } else {
            VaultOnboardingView()
        }
    }
}

private struct VaultOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vaultName = ""
    @State private var vaultDescription = ""

    private var trimmedName: String {
        vaultName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDescription: String {
        vaultDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Create Your Vault")
                    .font(.largeTitle.bold())
                Text("This vault will hold your notes and sync with iCloud when the app's CloudKit capability is enabled.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                TextField("Vault name", text: $vaultName)
                    .textFieldStyle(.roundedBorder)

                TextField("Description", text: $vaultDescription, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.roundedBorder)
            }

            Button(action: createVault) {
                Label("Create Vault", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmedName.isEmpty)
        }
        .frame(minWidth: 520, idealWidth: 620, maxWidth: 720, alignment: .leading)
        .padding(40)
    }

    private func createVault() {
        let description = trimmedDescription.isEmpty ? nil : trimmedDescription
        let vault = Vault(name: trimmedName, vaultDescription: description)
        modelContext.insert(vault)
    }
}

private struct NotesWorkspaceView: View {
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

private struct NoteDetailView: View {
    @Bindable var note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Title", text: $note.title)
                .font(.largeTitle.bold())
                .textFieldStyle(.plain)

            Text(note.markupFormat.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $note.body)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if note.body.isEmpty {
                        Text("Start writing...")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
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

#Preview {
    ContentView()
        .modelContainer(for: [Vault.self, NoteFolder.self, Note.self], inMemory: true)
}
