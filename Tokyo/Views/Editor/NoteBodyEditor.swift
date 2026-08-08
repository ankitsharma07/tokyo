//
//  NoteBodyEditor.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

struct NoteBodyEditor: View {
    @Bindable var note: Note
    @Query(sort: \Note.title) private var notes: [Note]

    private var shouldShowSlashCommands: Bool {
        note.markupFormat == .markdown && note.body.hasSuffix("/")
    }

    private var linkSuggestionContext: NoteLinkSuggestionContext? {
        guard note.markupFormat == .markdown else { return nil }
        return NoteLinkSuggestionContext(body: note.body)
    }

    private var linkSuggestions: [Note] {
        guard let context = linkSuggestionContext else { return [] }
        let query = context.query.trimmingCharacters(in: .whitespacesAndNewlines)

        return notes
            .filter { candidate in
                candidate.id != note.id &&
                candidate.vault?.id == note.vault?.id &&
                !candidate.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                (query.isEmpty || candidate.title.localizedCaseInsensitiveContains(query))
            }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        editor
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            bodyInput

            if note.body.isEmpty {
                Text("Start writing...")
                    .foregroundStyle(.tertiary)
                    .padding(.top, 16)
                    .padding(.leading, 12)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topLeading) {
            if shouldShowSlashCommands {
                SlashCommandMenu(noteBody: $note.body)
                    .padding(.top, 40)
                    .padding(.leading, 12)
            }
        }
        .overlay(alignment: .topLeading) {
            if let context = linkSuggestionContext, !linkSuggestions.isEmpty {
                NoteLinkSuggestionMenu(suggestions: linkSuggestions) { selectedNote in
                    applyLinkSuggestion(selectedNote, context: context)
                }
                .padding(.top, 40)
                .padding(.leading, 12)
            }
        }
    }

    @ViewBuilder
    private var bodyInput: some View {
        switch note.markupFormat {
        case .markdown:
            MarkdownLiveTextEditor(text: $note.body)
        case .org:
            TextEditor(text: $note.body)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(.top, 8)
        }
    }

    private func applyLinkSuggestion(_ selectedNote: Note, context: NoteLinkSuggestionContext) {
        note.body.replaceSubrange(context.replacementRange, with: "[[\(selectedNote.title)]]")
    }

}

#if os(macOS)
private struct MarkdownLiveTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.string = text
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)

        context.coordinator.applyMarkdownStyle(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            context.coordinator.isUpdatingFromSwiftUI = true
            textView.string = text
            context.coordinator.isUpdatingFromSwiftUI = false
        }

        context.coordinator.applyMarkdownStyle(to: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        var isUpdatingFromSwiftUI = false
        private var isApplyingStyle = false

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            if !isUpdatingFromSwiftUI {
                text = textView.string
            }

            applyMarkdownStyle(to: textView)
        }

        func applyMarkdownStyle(to textView: NSTextView) {
            guard !isApplyingStyle, let storage = textView.textStorage else { return }

            isApplyingStyle = true
            let selectedRanges = textView.selectedRanges
            let fullRange = NSRange(location: 0, length: storage.length)
            let source = textView.string as NSString

            storage.beginEditing()
            storage.setAttributes(baseAttributes(), range: fullRange)

            var isInCodeBlock = false
            source.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
                let line = source.substring(with: lineRange)
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)

                if trimmedLine.hasPrefix("```") {
                    storage.addAttributes(self.codeAttributes(), range: lineRange)
                    isInCodeBlock.toggle()
                    return
                }

                if isInCodeBlock {
                    storage.addAttributes(self.codeAttributes(), range: lineRange)
                    return
                }

                if let headingLevel = self.headingLevel(in: line) {
                    storage.addAttributes(self.headingAttributes(level: headingLevel), range: lineRange)
                    let markerRange = NSRange(location: lineRange.location, length: headingLevel)
                    storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: markerRange)
                    return
                }

                if trimmedLine.hasPrefix(">") {
                    storage.addAttributes(self.blockquoteAttributes(), range: lineRange)
                    self.styleLeadingMarker(in: line, lineRange: lineRange, marker: ">", storage: storage)
                    return
                }

                if self.isListLine(trimmedLine) {
                    self.styleListMarker(in: line, lineRange: lineRange, storage: storage)
                }

                self.applyInlineStyles(in: line, lineRange: lineRange, storage: storage)
            }

            storage.endEditing()
            textView.selectedRanges = selectedRanges
            isApplyingStyle = false
        }

        private func baseAttributes() -> [NSAttributedString.Key: Any] {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4
            paragraphStyle.paragraphSpacing = 6

            return [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ]
        }

        private func headingAttributes(level: Int) -> [NSAttributedString.Key: Any] {
            let size: CGFloat
            switch level {
            case 1: size = 30
            case 2: size = 24
            case 3: size = 20
            case 4: size = 17
            default: size = 15
            }

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4
            paragraphStyle.paragraphSpacingBefore = level == 1 ? 10 : 6
            paragraphStyle.paragraphSpacing = 8

            return [
                .font: NSFont.systemFont(ofSize: size, weight: .bold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ]
        }

        private func blockquoteAttributes() -> [NSAttributedString.Key: Any] {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = 12
            paragraphStyle.headIndent = 12
            paragraphStyle.lineSpacing = 4
            paragraphStyle.paragraphSpacing = 6

            return [
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
        }

        private func codeAttributes() -> [NSAttributedString.Key: Any] {
            [
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.16)
            ]
        }

        private func headingLevel(in line: String) -> Int? {
            let markerCount = line.prefix(while: { $0 == "#" }).count
            guard (1...6).contains(markerCount) else { return nil }
            let markerEndIndex = line.index(line.startIndex, offsetBy: markerCount)
            guard markerEndIndex < line.endIndex, line[markerEndIndex] == " " else { return nil }
            return markerCount
        }

        private func isListLine(_ trimmedLine: String) -> Bool {
            trimmedLine.hasPrefix("- ") ||
            trimmedLine.hasPrefix("* ") ||
            trimmedLine.hasPrefix("+ ") ||
            trimmedLine.hasPrefix("- [ ] ") ||
            trimmedLine.hasPrefix("- [x] ") ||
            trimmedLine.hasPrefix("- [X] ") ||
            trimmedLine.range(of: #"^\d+\. "#, options: .regularExpression) != nil
        }

        private func styleLeadingMarker(in line: String, lineRange: NSRange, marker: String, storage: NSTextStorage) {
            guard let markerRange = line.range(of: marker) else { return }
            let nsRange = NSRange(markerRange, in: line)
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: offset(nsRange, by: lineRange.location))
        }

        private func styleListMarker(in line: String, lineRange: NSRange, storage: NSTextStorage) {
            let markerPatterns = ["^\\s*[-*+] ", "^\\s*- \\[[ xX]\\] ", "^\\s*\\d+\\. "]

            for pattern in markerPatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else {
                    continue
                }

                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: offset(match.range, by: lineRange.location))
                return
            }
        }

        private func applyInlineStyles(in line: String, lineRange: NSRange, storage: NSTextStorage) {
            apply(pattern: #"\*\*([^*]+)\*\*"#, attributes: [.font: NSFont.systemFont(ofSize: 15, weight: .semibold)], in: line, lineRange: lineRange, storage: storage)
            apply(pattern: #"`([^`]+)`"#, attributes: codeAttributes(), in: line, lineRange: lineRange, storage: storage)
            apply(pattern: #"\[\[([^\]]+)\]\]"#, attributes: [.foregroundColor: NSColor.controlAccentColor, .underlineStyle: NSUnderlineStyle.single.rawValue], in: line, lineRange: lineRange, storage: storage)
        }

        private func apply(pattern: String, attributes: [NSAttributedString.Key: Any], in line: String, lineRange: NSRange, storage: NSTextStorage) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let fullLineRange = NSRange(location: 0, length: (line as NSString).length)
            for match in regex.matches(in: line, range: fullLineRange) {
                storage.addAttributes(attributes, range: offset(match.range, by: lineRange.location))
            }
        }

        private func offset(_ range: NSRange, by location: Int) -> NSRange {
            NSRange(location: range.location + location, length: range.length)
        }
    }
}
#else
private struct MarkdownLiveTextEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.body.monospaced())
            .scrollContentBackground(.hidden)
            .padding(.top, 8)
    }
}
#endif

private struct NoteLinkSuggestionMenu: View {
    let suggestions: [Note]
    let selection: (Note) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(suggestions) { note in
                Button {
                    selection(note)
                } label: {
                    Label(note.title, systemImage: "link")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
        }
        .padding(6)
        .frame(width: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.45))
        }
        .shadow(radius: 12, y: 4)
    }
}

private struct NoteLinkSuggestionContext {
    let query: String
    let replacementRange: Range<String.Index>

    init?(body: String) {
        let searchRange: Range<String.Index>
        if let lastClosedLink = body.range(of: "]]", options: .backwards) {
            searchRange = lastClosedLink.upperBound..<body.endIndex
        } else {
            searchRange = body.startIndex..<body.endIndex
        }

        guard let openingRange = body.range(of: "[[", options: .backwards, range: searchRange) else { return nil }
        let queryRange = openingRange.upperBound..<body.endIndex
        let query = String(body[queryRange])

        guard !query.contains("\n"), !query.contains("[") else { return nil }

        self.query = query
        self.replacementRange = openingRange.lowerBound..<body.endIndex
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
