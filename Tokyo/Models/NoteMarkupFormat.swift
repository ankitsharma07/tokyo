//
//  NoteMarkupFormat.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import Foundation

enum NoteMarkupFormat: String, Codable, CaseIterable, Identifiable {
    case markdown
    case org

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .markdown:
            "Markdown"
        case .org:
            "Org"
        }
    }
}
