//
//  AppSettingsView.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import SwiftUI
import SwiftData

struct AppSettingsView: View {
    @Query(sort: \Vault.createdAt) private var vaults: [Vault]

    var body: some View {
        Form {
            Section("New Notes") {
                if let vault = vaults.first {
                    Picker("Default format", selection: defaultNoteFormatBinding(for: vault)) {
                        ForEach(NoteMarkupFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                } else {
                    ContentUnavailableView("No Vault", systemImage: "folder", description: Text("Create a vault before choosing a note format."))
                }
            }
        }
        .formStyle(.grouped)
        .scenePadding()
        .frame(width: 420)
    }

    private func defaultNoteFormatBinding(for vault: Vault) -> Binding<NoteMarkupFormat> {
        Binding(
            get: { vault.defaultNoteFormat },
            set: { format in
                vault.defaultNoteFormat = format
                vault.updatedAt = Date()
            }
        )
    }
}
