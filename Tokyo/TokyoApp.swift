//
//  TokyoApp.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import SwiftUI
import SwiftData

@main
struct TokyoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Vault.self,
            NoteFolder.self,
            Note.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
