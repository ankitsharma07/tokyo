//
//  VaultOnboardingView.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import SwiftUI
import SwiftData

struct VaultOnboardingView: View {
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
