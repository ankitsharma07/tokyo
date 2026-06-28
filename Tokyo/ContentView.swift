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

#Preview {
    ContentView()
        .modelContainer(for: [Vault.self, NoteFolder.self, Note.self], inMemory: true)
}
