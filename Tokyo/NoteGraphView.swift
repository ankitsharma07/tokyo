//
//  NoteGraphView.swift
//  Tokyo
//
//  Created by Ankit Sharma on 12/04/26.
//

import SwiftUI

struct NoteGraphView: View {
    let graph: NoteGraph
    let selectedNoteID: UUID?
    let noteSelection: (UUID) -> Void

    private var connectedNodeIDs: Set<UUID> {
        Set(graph.edges.flatMap { [$0.sourceID, $0.targetID] })
    }

    private var notesByID: [UUID: NoteGraphNode] {
        Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
    }

    var body: some View {
        HSplitView {
            graphCanvas
                .frame(minWidth: 420)

            connectionList
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
        }
        .navigationTitle("Graph")
    }

    @ViewBuilder
    private var graphCanvas: some View {
        if graph.nodes.isEmpty {
            ContentUnavailableView("No Notes", systemImage: "point.3.connected.trianglepath.dotted", description: Text("Create notes to build the graph."))
        } else {
            GeometryReader { proxy in
                let positions = nodePositions(in: proxy.size)

                ZStack {
                    Canvas { context, _ in
                        for edge in graph.edges {
                            guard
                                let source = positions[edge.sourceID],
                                let target = positions[edge.targetID]
                            else { continue }

                            var path = Path()
                            path.move(to: source)
                            path.addLine(to: target)
                            context.stroke(path, with: .color(.secondary.opacity(0.45)), lineWidth: 1.5)
                        }
                    }

                    ForEach(graph.nodes) { node in
                        let isSelected = selectedNoteID == node.id
                        let isConnected = connectedNodeIDs.contains(node.id)

                        Button {
                            noteSelection(node.id)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: isConnected ? "doc.text.fill" : "doc.text")
                                    .font(.title3)
                                Text(node.title.isEmpty ? "Untitled" : node.title)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 112)
                            }
                            .padding(10)
                            .background(isSelected ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isSelected ? 2 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .position(positions[node.id] ?? CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2))
                    }
                }
                .padding(24)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var connectionList: some View {
        List {
            Section("Notes") {
                ForEach(graph.nodes) { node in
                    Button {
                        noteSelection(node.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: connectedNodeIDs.contains(node.id) ? "circle.hexagongrid.fill" : "circle")
                                .foregroundStyle(connectedNodeIDs.contains(node.id) ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(node.title.isEmpty ? "Untitled" : node.title)
                                    .lineLimit(1)
                                Text(connectionSummary(for: node.id))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Links") {
                if graph.edges.isEmpty {
                    Text("Add [[Note Title]] links in note bodies to connect notes.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(graph.edges) { edge in
                        if let source = notesByID[edge.sourceID], let target = notesByID[edge.targetID] {
                            HStack(spacing: 6) {
                                Text(source.title.isEmpty ? "Untitled" : source.title)
                                    .lineLimit(1)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(target.title.isEmpty ? "Untitled" : target.title)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func connectionSummary(for noteID: UUID) -> String {
        let outgoing = graph.edges.filter { $0.sourceID == noteID }.count
        let incoming = graph.edges.filter { $0.targetID == noteID }.count
        return "\(outgoing) out, \(incoming) in"
    }

    private func nodePositions(in size: CGSize) -> [UUID: CGPoint] {
        guard !graph.nodes.isEmpty else { return [:] }

        let availableWidth = max(size.width - 180, 120)
        let availableHeight = max(size.height - 140, 120)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radiusX = availableWidth / 2
        let radiusY = availableHeight / 2

        if graph.nodes.count == 1, let node = graph.nodes.first {
            return [node.id: center]
        }

        return Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { index, node in
            let angle = (Double(index) / Double(graph.nodes.count)) * 2 * Double.pi - Double.pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radiusX,
                y: center.y + sin(angle) * radiusY
            )
            return (node.id, point)
        })
    }
}
