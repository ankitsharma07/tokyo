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

    @State private var positions: [UUID: CGPoint] = [:]
    @State private var velocities: [UUID: CGVector] = [:]
    @State private var draggedNodeID: UUID?
    @State private var canvasSize: CGSize = .zero

    private var connectedNodeIDs: Set<UUID> {
        Set(graph.edges.flatMap { [$0.sourceID, $0.targetID] })
    }

    private var notesByID: [UUID: NoteGraphNode] {
        Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
    }

    private var simulationKey: String {
        let nodeKey = graph.nodes.map(\.id.uuidString).sorted().joined(separator: ",")
        let edgeKey = graph.edges.map(\.id).sorted().joined(separator: ",")
        return nodeKey + "|" + edgeKey
    }

    var body: some View {
        HSplitView {
            graphCanvas
                .frame(minWidth: 520)

            connectionList
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
        }
        .navigationTitle("Graph")
        .task(id: simulationKey) {
            await runSimulationLoop()
        }
    }

    @ViewBuilder
    private var graphCanvas: some View {
        if graph.nodes.isEmpty {
            ContentUnavailableView("No Notes", systemImage: "point.3.connected.trianglepath.dotted", description: Text("Create notes to build the graph."))
        } else {
            GeometryReader { proxy in
                ZStack {
                    Color(nsColor: .textBackgroundColor)

                    Canvas { context, _ in
                        for edge in graph.edges {
                            guard
                                let source = positions[edge.sourceID],
                                let target = positions[edge.targetID]
                            else { continue }

                            var path = Path()
                            path.move(to: source)
                            path.addLine(to: target)

                            let isSelectedEdge = edge.sourceID == selectedNoteID || edge.targetID == selectedNoteID
                            context.stroke(
                                path,
                                with: .color(isSelectedEdge ? Color.accentColor.opacity(0.65) : Color.secondary.opacity(0.42)),
                                lineWidth: isSelectedEdge ? 2.4 : 1.4
                            )
                        }
                    }

                    ForEach(graph.nodes) { node in
                        GraphNodeView(
                            node: node,
                            isSelected: selectedNoteID == node.id,
                            isConnected: connectedNodeIDs.contains(node.id),
                            connectionCount: connectionCount(for: node.id)
                        )
                        .position(positions[node.id] ?? center(in: proxy.size))
                        .gesture(
                            DragGesture(minimumDistance: 2, coordinateSpace: .named("NoteGraphCanvas"))
                                .onChanged { value in
                                    draggedNodeID = node.id
                                    positions[node.id] = clamped(value.location, in: proxy.size)
                                    velocities[node.id] = .zero
                                }
                                .onEnded { _ in
                                    draggedNodeID = nil
                                }
                        )
                        .onTapGesture {
                            noteSelection(node.id)
                        }
                    }
                }
                .clipShape(Rectangle())
                .coordinateSpace(name: "NoteGraphCanvas")
                .onAppear {
                    canvasSize = proxy.size
                    initializePositionsIfNeeded(in: proxy.size)
                }
                .onChange(of: proxy.size) { _, newSize in
                    canvasSize = newSize
                    initializePositionsIfNeeded(in: newSize)
                }
                .onChange(of: simulationKey) { _, _ in
                    initializePositions(in: proxy.size)
                }
            }
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

    private func runSimulationLoop() async {
        await MainActor.run {
            initializePositionsIfNeeded(in: canvasSize)
        }

        while !Task.isCancelled {
            await MainActor.run {
                stepSimulation(in: canvasSize)
            }
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
    }

    private func initializePositionsIfNeeded(in size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let nodeIDs = Set(graph.nodes.map(\.id))
        let positionedIDs = Set(positions.keys)

        if nodeIDs != positionedIDs {
            initializePositions(in: size)
        }
    }

    private func initializePositions(in size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }

        let center = center(in: size)
        let radius = max(min(size.width, size.height) * 0.24, 90)
        var nextPositions: [UUID: CGPoint] = [:]
        var nextVelocities: [UUID: CGVector] = [:]

        for (index, node) in graph.nodes.enumerated() {
            if let existingPosition = positions[node.id] {
                nextPositions[node.id] = clamped(existingPosition, in: size)
            } else if graph.nodes.count == 1 {
                nextPositions[node.id] = center
            } else {
                let angle = (Double(index) / Double(graph.nodes.count)) * 2 * Double.pi
                nextPositions[node.id] = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
            }
            nextVelocities[node.id] = velocities[node.id] ?? .zero
        }

        positions = nextPositions
        velocities = nextVelocities
    }

    private func stepSimulation(in size: CGSize) {
        guard size.width > 1, size.height > 1, graph.nodes.count > 1 else { return }

        initializePositionsIfNeeded(in: size)

        let nodeIDs = graph.nodes.map(\.id)
        let center = center(in: size)
        var forces = Dictionary(uniqueKeysWithValues: nodeIDs.map { ($0, CGVector.zero) })
        let idealLinkLength = max(min(size.width, size.height) * 0.22, 150)
        let repulsion: CGFloat = 7_500
        let linkStrength: CGFloat = 0.018
        let centerStrength: CGFloat = graph.edges.isEmpty ? 0.012 : 0.006
        let damping: CGFloat = 0.84
        let maxVelocity: CGFloat = 18

        for (firstIndex, firstID) in nodeIDs.enumerated() {
            guard let firstPosition = positions[firstID] else { continue }

            for secondID in nodeIDs.dropFirst(firstIndex + 1) {
                guard let secondPosition = positions[secondID] else { continue }

                let delta = firstPosition.vector(to: secondPosition)
                let distance = max(delta.length, 28)
                let direction = delta.normalized
                let force = repulsion / (distance * distance)
                forces[firstID, default: .zero] -= direction * force
                forces[secondID, default: .zero] += direction * force
            }
        }

        for edge in graph.edges {
            guard
                let sourcePosition = positions[edge.sourceID],
                let targetPosition = positions[edge.targetID]
            else { continue }

            let delta = sourcePosition.vector(to: targetPosition)
            let distance = max(delta.length, 1)
            let direction = delta.normalized
            let force = (distance - idealLinkLength) * linkStrength
            forces[edge.sourceID, default: .zero] += direction * force
            forces[edge.targetID, default: .zero] -= direction * force
        }

        for id in nodeIDs where draggedNodeID != id {
            guard let position = positions[id] else { continue }

            let centerDelta = position.vector(to: center)
            forces[id, default: .zero] += centerDelta * centerStrength

            var velocity = (velocities[id] ?? .zero) + (forces[id] ?? .zero)
            velocity *= damping
            velocity = velocity.limited(to: maxVelocity)

            velocities[id] = velocity
            positions[id] = clamped(position + velocity, in: size)
        }
    }

    private func connectionSummary(for noteID: UUID) -> String {
        let outgoing = graph.edges.filter { $0.sourceID == noteID }.count
        let incoming = graph.edges.filter { $0.targetID == noteID }.count
        return "\(outgoing) out, \(incoming) in"
    }

    private func connectionCount(for noteID: UUID) -> Int {
        graph.edges.filter { $0.sourceID == noteID || $0.targetID == noteID }.count
    }

    private func center(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func clamped(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 76), max(size.width - 76, 76)),
            y: min(max(point.y, 58), max(size.height - 58, 58))
        )
    }
}

private struct GraphNodeView: View {
    let node: NoteGraphNode
    let isSelected: Bool
    let isConnected: Bool
    let connectionCount: Int

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(isSelected ? Color.accentColor.opacity(0.22) : Color(nsColor: .controlBackgroundColor))
                    .frame(width: diameter, height: diameter)
                    .shadow(color: .black.opacity(0.12), radius: isSelected ? 10 : 5, y: 3)
                    .overlay {
                        Circle()
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.28), lineWidth: isSelected ? 2.4 : 1)
                    }
                    .overlay {
                        Image(systemName: isConnected ? "doc.text.fill" : "doc.text")
                            .font(.title2)
                            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    }

                if connectionCount > 0 {
                    Text("\(connectionCount)")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Color.accentColor, in: Circle())
                        .offset(x: 2, y: -2)
                }
            }

            Text(node.title.isEmpty ? "Untitled" : node.title)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 128)
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: isSelected)
    }

    private var diameter: CGFloat {
        min(86 + CGFloat(connectionCount) * 5, 122)
    }
}

private extension CGPoint {
    func vector(to point: CGPoint) -> CGVector {
        CGVector(dx: point.x - x, dy: point.y - y)
    }

    static func + (point: CGPoint, vector: CGVector) -> CGPoint {
        CGPoint(x: point.x + vector.dx, y: point.y + vector.dy)
    }
}

private extension CGVector {
    static func + (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }

    static func += (lhs: inout CGVector, rhs: CGVector) {
        lhs = lhs + rhs
    }

    static func - (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
    }

    static func -= (lhs: inout CGVector, rhs: CGVector) {
        lhs = lhs - rhs
    }

    static func * (vector: CGVector, scalar: CGFloat) -> CGVector {
        CGVector(dx: vector.dx * scalar, dy: vector.dy * scalar)
    }

    static func *= (vector: inout CGVector, scalar: CGFloat) {
        vector = vector * scalar
    }

    var length: CGFloat {
        sqrt(dx * dx + dy * dy)
    }

    var normalized: CGVector {
        guard length > 0 else { return .zero }
        return CGVector(dx: dx / length, dy: dy / length)
    }

    func limited(to maximumLength: CGFloat) -> CGVector {
        guard length > maximumLength else { return self }
        return normalized * maximumLength
    }
}
