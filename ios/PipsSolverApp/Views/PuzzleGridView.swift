import SwiftUI

struct PuzzleGridView: View {
    let puzzle: Puzzle
    let cellValues: [GridPosition: Int]
    let visibleDominoes: [PlacedDomino]
    let solveMode: SolveMode
    var onCellTap: ((GridPosition) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    private var dominoPairs: [GridPosition: GridPosition] {
        var pairs: [GridPosition: GridPosition] = [:]
        for placed in visibleDominoes {
            pairs[placed.position1] = placed.position2
            pairs[placed.position2] = placed.position1
        }
        return pairs
    }

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 3
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            let cellW = (availableWidth - CGFloat(puzzle.cols - 1) * spacing) / CGFloat(puzzle.cols)
            let cellH = (availableHeight - CGFloat(puzzle.rows - 1) * spacing) / CGFloat(puzzle.rows)
            let cellSize = min(cellW, cellH, 72)
            let totalW = CGFloat(puzzle.cols) * cellSize + CGFloat(puzzle.cols - 1) * spacing
            let totalH = CGFloat(puzzle.rows) * cellSize + CGFloat(puzzle.rows - 1) * spacing

            ZStack(alignment: .topLeading) {
                ForEach(0..<puzzle.rows, id: \.self) { row in
                    ForEach(0..<puzzle.cols, id: \.self) { col in
                        let pos = GridPosition(row: row, col: col)
                        let x = CGFloat(col) * (cellSize + spacing)
                        let y = CGFloat(row) * (cellSize + spacing)

                        if puzzle.activeCells.contains(pos) {
                            cellView(for: pos, size: cellSize)
                                .frame(width: cellSize, height: cellSize)
                                .position(x: x + cellSize / 2, y: y + cellSize / 2)
                        }
                    }
                }

                ForEach(visibleDominoes, id: \.id) { placed in
                    let p1 = placed.position1
                    let p2 = placed.position2
                    let x1 = CGFloat(p1.col) * (cellSize + spacing) + cellSize / 2
                    let y1 = CGFloat(p1.row) * (cellSize + spacing) + cellSize / 2
                    let x2 = CGFloat(p2.col) * (cellSize + spacing) + cellSize / 2
                    let y2 = CGFloat(p2.row) * (cellSize + spacing) + cellSize / 2

                    let isHorizontal = p1.row == p2.row
                    let connX = (x1 + x2) / 2
                    let connY = (y1 + y2) / 2

                    if isHorizontal {
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
                            .frame(width: spacing + 4, height: cellSize * 0.5)
                            .position(x: connX, y: connY)
                    } else {
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
                            .frame(width: cellSize * 0.5, height: spacing + 4)
                            .position(x: connX, y: connY)
                    }
                }

                ForEach(puzzle.regions) { region in
                    if region.constraint.hasConstraint {
                        let badgePos = bestBadgePosition(for: region, cellSize: cellSize, spacing: spacing)
                        constraintBadge(region.constraint, color: RegionColors.color(for: region.colorIndex))
                            .position(x: badgePos.x, y: badgePos.y)
                    }
                }
            }
            .frame(width: totalW, height: totalH)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func cellView(for position: GridPosition, size: CGFloat) -> some View {
        let region = puzzle.regionFor(cell: position)
        let colorIndex = region?.colorIndex ?? 0
        let baseColor = RegionColors.color(for: colorIndex)
        let pipValue = cellValues[position]
        let hasPip = pipValue != nil
        let isHintMode = solveMode == .hint && !hasPip
        let partner = dominoPairs[position]

        let sameRegionNeighbors = position.neighbors.filter { neighbor in
            guard let regionId = puzzle.cellRegionMap[position],
                  let neighborRegionId = puzzle.cellRegionMap[neighbor] else { return false }
            return regionId == neighborRegionId
        }

        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(baseColor.opacity(hasPip ? 0.25 : 0.5))

            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    baseColor.opacity(0.6),
                    style: StrokeStyle(lineWidth: 1.5, dash: hasPip ? [] : [4, 3])
                )

            if let pip = pipValue {
                RoundedRectangle(cornerRadius: 5)
                    .fill(colorScheme == .dark
                          ? Color(.tertiarySystemBackground)
                          : .white)
                    .padding(3)

                PipDotsView(
                    value: pip,
                    size: size * 0.65,
                    dotColor: colorScheme == .dark ? .white : Color(white: 0.15)
                )
            }

            if isHintMode {
                Image(systemName: "questionmark")
                    .font(.system(size: size * 0.25, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.4))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onCellTap?(position)
        }
    }

    private func bestBadgePosition(for region: Region, cellSize: CGFloat, spacing: CGFloat) -> CGPoint {
        let sorted = region.cells.sorted { a, b in
            if a.row != b.row { return a.row > b.row }
            return a.col > b.col
        }

        for cell in sorted {
            let right = GridPosition(row: cell.row, col: cell.col + 1)
            let below = GridPosition(row: cell.row + 1, col: cell.col)
            let isRightEdge = !region.cells.contains(right)
            let isBottomEdge = !region.cells.contains(below)

            if isRightEdge || isBottomEdge {
                let x = CGFloat(cell.col) * (cellSize + spacing) + cellSize
                let y = CGFloat(cell.row) * (cellSize + spacing) + cellSize
                return CGPoint(x: x, y: y)
            }
        }

        let center = region.centerCell
        let x = CGFloat(center.col) * (cellSize + spacing) + cellSize / 2
        let y = CGFloat(center.row) * (cellSize + spacing) + cellSize / 2
        return CGPoint(x: x, y: y)
    }

    private func constraintBadge(_ constraint: ConstraintType, color: Color) -> some View {
        Text(constraint.displayText)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                Diamond()
                    .fill(color.opacity(0.9))
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            )
            .allowsHitTesting(false)
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: rect.midX, y: rect.minY - h * 0.15))
        path.addLine(to: CGPoint(x: rect.maxX + w * 0.15, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY + h * 0.15))
        path.addLine(to: CGPoint(x: rect.minX - w * 0.15, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
