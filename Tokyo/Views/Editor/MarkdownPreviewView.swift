//
//  MarkdownPreviewView.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct MarkdownPreviewView: View {
    let markdown: String

    private var blocks: [MarkdownBlock] {
        MarkdownBlockParser.parse(markdown)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if blocks.isEmpty {
                    Text("Preview")
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(blocks) { block in
                        view(for: block)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(16)
        }
        .background(.background)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level, let text):
            Text(inlineMarkdown: text)
                .font(font(forHeadingLevel: level))
                .padding(.top, level == 1 ? 8 : 4)
        case .paragraph(let text):
            Text(inlineMarkdown: text)
                .font(.body)
                .textSelection(.enabled)
        case .blockquote(let text):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(.secondary.opacity(0.45))
                    .frame(width: 3)
                Text(inlineMarkdown: text)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(.vertical, 4)
        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                        Text(inlineMarkdown: item.text)
                    }
                }
            }
        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(item.ordinal).")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(inlineMarkdown: item.text)
                    }
                }
            }
        case .taskList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: item.isComplete ? "checkmark.square.fill" : "square")
                            .foregroundStyle(item.isComplete ? Color.accentColor : Color.secondary)
                        Text(inlineMarkdown: item.text)
                    }
                }
            }
        case .codeBlock(let code):
            CodeBlockPreview(code: code)
        case .horizontalRule:
            Divider()
                .padding(.vertical, 6)
        }
    }

    private func font(forHeadingLevel level: Int) -> Font {
        switch level {
        case 1:
            .largeTitle.bold()
        case 2:
            .title.bold()
        case 3:
            .title2.bold()
        case 4:
            .title3.bold()
        case 5:
            .headline
        default:
            .subheadline.bold()
        }
    }
}

private struct CodeBlockPreview: View {
    let code: String
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()

                Button {
                    copyCode()
                } label: {
                    Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help(didCopy ? "Copied" : "Copy code")
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            Text(code.isEmpty ? " " : code)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 12)
        }
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }

    private func copyCode() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif

        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            didCopy = false
        }
    }
}

private struct MarkdownBlock: Identifiable {
    enum Kind {
        case heading(level: Int, text: String)
        case paragraph(String)
        case blockquote(String)
        case unorderedList([MarkdownListItem])
        case orderedList([MarkdownOrderedListItem])
        case taskList([MarkdownTaskListItem])
        case codeBlock(String)
        case horizontalRule
    }

    let id = UUID()
    let kind: Kind
}

private struct MarkdownListItem: Identifiable {
    let id = UUID()
    let text: String
}

private struct MarkdownOrderedListItem: Identifiable {
    let id = UUID()
    let ordinal: Int
    let text: String
}

private struct MarkdownTaskListItem: Identifiable {
    let id = UUID()
    let isComplete: Bool
    let text: String
}

private enum MarkdownBlockParser {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []
        var codeLines: [String] = []
        var unorderedItems: [MarkdownListItem] = []
        var orderedItems: [MarkdownOrderedListItem] = []
        var taskItems: [MarkdownTaskListItem] = []
        var quoteLines: [String] = []
        var isInCodeBlock = false

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            blocks.append(MarkdownBlock(kind: .paragraph(paragraphLines.joined(separator: "\n"))))
            paragraphLines.removeAll()
        }

        func flushUnorderedList() {
            guard !unorderedItems.isEmpty else { return }
            blocks.append(MarkdownBlock(kind: .unorderedList(unorderedItems)))
            unorderedItems.removeAll()
        }

        func flushOrderedList() {
            guard !orderedItems.isEmpty else { return }
            blocks.append(MarkdownBlock(kind: .orderedList(orderedItems)))
            orderedItems.removeAll()
        }

        func flushTaskList() {
            guard !taskItems.isEmpty else { return }
            blocks.append(MarkdownBlock(kind: .taskList(taskItems)))
            taskItems.removeAll()
        }

        func flushBlockquote() {
            guard !quoteLines.isEmpty else { return }
            blocks.append(MarkdownBlock(kind: .blockquote(quoteLines.joined(separator: "\n"))))
            quoteLines.removeAll()
        }

        func flushOpenBlocks() {
            flushParagraph()
            flushUnorderedList()
            flushOrderedList()
            flushTaskList()
            flushBlockquote()
        }

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.hasPrefix("```") {
                if isInCodeBlock {
                    blocks.append(MarkdownBlock(kind: .codeBlock(codeLines.joined(separator: "\n"))))
                    codeLines.removeAll()
                    isInCodeBlock = false
                } else {
                    flushOpenBlocks()
                    isInCodeBlock = true
                }
                continue
            }

            if isInCodeBlock {
                codeLines.append(line)
                continue
            }

            if trimmedLine.isEmpty {
                flushOpenBlocks()
                continue
            }

            if isHorizontalRule(trimmedLine) {
                flushOpenBlocks()
                blocks.append(MarkdownBlock(kind: .horizontalRule))
                continue
            }

            if let heading = heading(from: line) {
                flushOpenBlocks()
                blocks.append(MarkdownBlock(kind: .heading(level: heading.level, text: heading.text)))
                continue
            }

            if let quote = blockquote(from: line) {
                flushParagraph()
                flushUnorderedList()
                flushOrderedList()
                flushTaskList()
                quoteLines.append(quote)
                continue
            }

            if let taskItem = taskListItem(from: trimmedLine) {
                flushParagraph()
                flushUnorderedList()
                flushOrderedList()
                flushBlockquote()
                taskItems.append(taskItem)
                continue
            }

            if let unorderedItem = unorderedListItem(from: trimmedLine) {
                flushParagraph()
                flushOrderedList()
                flushTaskList()
                flushBlockquote()
                unorderedItems.append(MarkdownListItem(text: unorderedItem))
                continue
            }

            if let orderedItem = orderedListItem(from: trimmedLine) {
                flushParagraph()
                flushUnorderedList()
                flushTaskList()
                flushBlockquote()
                orderedItems.append(orderedItem)
                continue
            }

            flushUnorderedList()
            flushOrderedList()
            flushTaskList()
            flushBlockquote()
            paragraphLines.append(line)
        }

        if isInCodeBlock {
            blocks.append(MarkdownBlock(kind: .codeBlock(codeLines.joined(separator: "\n"))))
        }
        flushOpenBlocks()

        return blocks
    }

    private static func heading(from line: String) -> (level: Int, text: String)? {
        guard line.hasPrefix("#") else { return nil }
        let markerCount = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(markerCount) else { return nil }

        let markerEndIndex = line.index(line.startIndex, offsetBy: markerCount)
        guard markerEndIndex < line.endIndex, line[markerEndIndex] == " " else { return nil }

        let textStartIndex = line.index(after: markerEndIndex)
        return (markerCount, String(line[textStartIndex...]))
    }

    private static func blockquote(from line: String) -> String? {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        guard trimmedLine.hasPrefix(">") else { return nil }
        let text = trimmedLine.dropFirst().trimmingCharacters(in: .whitespaces)
        return String(text)
    }

    private static func unorderedListItem(from trimmedLine: String) -> String? {
        for marker in ["- ", "* ", "+ "] where trimmedLine.hasPrefix(marker) {
            return String(trimmedLine.dropFirst(marker.count))
        }
        return nil
    }

    private static func orderedListItem(from trimmedLine: String) -> MarkdownOrderedListItem? {
        guard let dotIndex = trimmedLine.firstIndex(of: ".") else { return nil }
        let numberText = trimmedLine[..<dotIndex]
        guard let ordinal = Int(numberText) else { return nil }

        let textStart = trimmedLine.index(after: dotIndex)
        guard textStart < trimmedLine.endIndex, trimmedLine[textStart] == " " else { return nil }

        return MarkdownOrderedListItem(ordinal: ordinal, text: String(trimmedLine[trimmedLine.index(after: textStart)...]))
    }

    private static func taskListItem(from trimmedLine: String) -> MarkdownTaskListItem? {
        let uncheckedPrefix = "- [ ] "
        let checkedPrefixes = ["- [x] ", "- [X] "]

        if trimmedLine.hasPrefix(uncheckedPrefix) {
            return MarkdownTaskListItem(isComplete: false, text: String(trimmedLine.dropFirst(uncheckedPrefix.count)))
        }

        for prefix in checkedPrefixes where trimmedLine.hasPrefix(prefix) {
            return MarkdownTaskListItem(isComplete: true, text: String(trimmedLine.dropFirst(prefix.count)))
        }

        return nil
    }

    private static func isHorizontalRule(_ trimmedLine: String) -> Bool {
        guard trimmedLine.count >= 3 else { return false }
        let characters = Set(trimmedLine)
        return characters == ["-"] || characters == ["*"] || characters == ["_"]
    }
}

private extension Text {
    init(inlineMarkdown source: String) {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        let attributedString = (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
        self.init(attributedString)
    }
}
