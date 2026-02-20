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
            let spacing: CGFloat = 2
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            let cellW = (availableWidth - CGFloat(puzzle.cols - 1) * spacing) / CGFloat(puzzle.cols)
            let cellH = (availableHeight - CGFloat(puzzle.rows - 1) * spacing) / CGFloat(puzzle.rows)
            let cellSize = min(cellW, cellH, 80)
            let totalW = CGFloat(puzzle.cols) * cellSize + CGFloat(puzzle.cols - 1) * spacing
            let totalH = CGFloat(puzzle.rows) * cellSize + CGFloat(puzzle.rows - 1) * spacing

            VStack(spacing: spacing) {
                ForEach(0..<puzzle.rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<puzzle.cols, id: \.self) { col in
                            let pos = GridPosition(row: row, col: col)
                            if puzzle.activeCells.contains(pos) {
                                cellView(for: pos, size: cellSize)
                            } else {
                                Color.clear
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
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

        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(baseColor.opacity(hasPip ? 0.3 : 0.6))

            if let pip = pipValue {
                RoundedRectangle(cornerRadius: 4)
                    .fill(colorScheme == .dark
                          ? Color(.secondarySystemBackground)
                          : .white)
                    .padding(2)

                PipDotsView(
                    value: pip,
                    size: size * 0.7,
                    dotColor: colorScheme == .dark ? .white : Color(white: 0.15)
                )
            }

            if let constraint = region?.constraint, constraint.hasConstraint {
                if region?.centerCell == position {
                    constraintBadge(constraint, size: size)
                }
            }

            if isHintMode {
                Image(systemName: "questionmark")
                    .font(.system(size: size * 0.3, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture {
            onCellTap?(position)
        }
    }

    private func constraintBadge(_ constraint: ConstraintType, size: CGFloat) -> some View {
        Text(constraint.displayText)
            .font(.system(size: max(9, size * 0.22), weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(.black.opacity(0.6))
            )
            .allowsHitTesting(false)
    }
}
