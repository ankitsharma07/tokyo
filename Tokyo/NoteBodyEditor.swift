//
//  NoteBodyEditor.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import SwiftUI
import SwiftData

struct NoteBodyEditor: View {
    @Bindable var note: Note
    @State private var isPreviewExpanded = false

    private var shouldShowSlashCommands: Bool {
        !isPreviewExpanded && note.markupFormat == .markdown && note.body.hasSuffix("/")
    }

    var body: some View {
        Group {
            if isPreviewExpanded {
                VStack(spacing: 0) {
                    PaneHeader(title: "Preview", systemImage: "doc.richtext", isPreviewExpanded: $isPreviewExpanded)
                    preview
                }
            } else {
                HSplitView {
                    VStack(spacing: 0) {
                        PaneHeader(title: "Editor", systemImage: "pencil.line", isPreviewExpanded: nil)
                        editor
                    }
                    .frame(minWidth: 280)

                    VStack(spacing: 0) {
                        PaneHeader(title: "Preview", systemImage: "doc.richtext", isPreviewExpanded: $isPreviewExpanded)
                        preview
                    }
                    .frame(minWidth: 280)
                }
            }
        }
        .animation(.default, value: isPreviewExpanded)
    }

    private var editor: some View {
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
            .overlay(alignment: .topLeading) {
                if shouldShowSlashCommands {
                    SlashCommandMenu(noteBody: $note.body)
                        .padding(.top, 32)
                        .padding(.leading, 12)
                }
            }
            .padding(.top, 8)
    }

    @ViewBuilder
    private var preview: some View {
        switch note.markupFormat {
        case .markdown:
            MarkdownPreviewView(markdown: note.body)
        case .org:
            PlainTextPreviewView(text: note.body)
        }
    }
}

private struct PaneHeader: View {
    let title: String
    let systemImage: String
    let isPreviewExpanded: Binding<Bool>?

    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            if let isPreviewExpanded {
                Button {
                    isPreviewExpanded.wrappedValue.toggle()
                } label: {
                    Image(systemName: isPreviewExpanded.wrappedValue ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.borderless)
                .help(isPreviewExpanded.wrappedValue ? "Collapse preview" : "Expand preview")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.35))
    }
}

private struct SlashCommandMenu: View {
    @Binding var noteBody: String

    private let commands: [SlashCommand] = [
        SlashCommand(title: "Heading 1", systemImage: "textformat.size.larger", replacement: "# Heading 1"),
        SlashCommand(title: "Heading 2", systemImage: "textformat.size", replacement: "## Heading 2"),
        SlashCommand(title: "Heading 3", systemImage: "textformat", replacement: "### Heading 3"),
        SlashCommand(title: "Quote", systemImage: "quote.opening", replacement: "> Quote"),
        SlashCommand(title: "Bulleted List", systemImage: "list.bullet", replacement: "- List item"),
        SlashCommand(title: "Numbered List", systemImage: "list.number", replacement: "1. List item"),
        SlashCommand(title: "Task List", systemImage: "checklist", replacement: "- [ ] Task"),
        SlashCommand(title: "Code Block", systemImage: "curlybraces", replacement: "```\ncode\n```"),
        SlashCommand(title: "Divider", systemImage: "minus", replacement: "---"),
        SlashCommand(title: "Table", systemImage: "tablecells", replacement: "| Column | Column |\n| --- | --- |\n| Value | Value |"),
        SlashCommand(title: "Table of Contents", systemImage: "list.bullet.indent", replacement: nil)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(commands) { command in
                Button {
                    apply(command)
                } label: {
                    Label(command.title, systemImage: command.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
        }
        .padding(6)
        .frame(width: 240)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.45))
        }
        .shadow(radius: 12, y: 4)
    }

    private func apply(_ command: SlashCommand) {
        guard noteBody.hasSuffix("/") else { return }
        noteBody.removeLast()

        let replacement = command.replacement ?? tableOfContents()
        if !noteBody.isEmpty, !noteBody.hasSuffix("\n") {
            noteBody.append("\n")
        }
        noteBody.append(replacement)
        noteBody.append("\n")
    }

    private func tableOfContents() -> String {
        let headings = noteBody
            .components(separatedBy: .newlines)
            .compactMap(heading)

        guard !headings.isEmpty else {
            return "## Table of Contents\n- Add headings to generate a table of contents."
        }

        let items = headings.map { heading in
            let indent = String(repeating: "  ", count: max(heading.level - 1, 0))
            return "\(indent)- \(heading.title)"
        }
        return (["## Table of Contents"] + items).joined(separator: "\n")
    }

    private func heading(from line: String) -> (level: Int, title: String)? {
        guard line.hasPrefix("#") else { return nil }
        let markerCount = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(markerCount) else { return nil }

        let markerEndIndex = line.index(line.startIndex, offsetBy: markerCount)
        guard markerEndIndex < line.endIndex, line[markerEndIndex] == " " else { return nil }

        let textStartIndex = line.index(after: markerEndIndex)
        let title = String(line[textStartIndex...]).trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return nil }
        return (markerCount, title)
    }
}

private struct SlashCommand: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let replacement: String?
}

private struct PlainTextPreviewView: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text.isEmpty ? "Preview" : text)
                .font(.body.monospaced())
                .foregroundStyle(text.isEmpty ? .tertiary : .primary)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(16)
        }
        .background(.background)
    }
}
