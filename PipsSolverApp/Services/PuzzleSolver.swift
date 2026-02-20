import Foundation

nonisolated final class PuzzleSolver: Sendable {

    func solve(_ puzzle: Puzzle) -> [PlacedDomino]? {
        let sortedCells = puzzle.activeCells.sorted { a, b in
            if a.row != b.row { return a.row < b.row }
            return a.col < b.col
        }
        var cellValues: [GridPosition: Int] = [:]
        var coveredCells: Set<GridPosition> = []
        var usedDominoes: Set<String> = []
        var result: [PlacedDomino] = []

        let adjacency = buildAdjacency(puzzle: puzzle)

        if backtrack(
            puzzle: puzzle,
            sortedCells: sortedCells,
            adjacency: adjacency,
            cellValues: &cellValues,
            coveredCells: &coveredCells,
            usedDominoes: &usedDominoes,
            result: &result
        ) {
            return result
        }
        return nil
    }

    private func buildAdjacency(puzzle: Puzzle) -> [GridPosition: [GridPosition]] {
        var adj: [GridPosition: [GridPosition]] = [:]
        for cell in puzzle.activeCells {
            adj[cell] = cell.neighbors.filter { puzzle.activeCells.contains($0) }
        }
        return adj
    }

    private func backtrack(
        puzzle: Puzzle,
        sortedCells: [GridPosition],
        adjacency: [GridPosition: [GridPosition]],
        cellValues: inout [GridPosition: Int],
        coveredCells: inout Set<GridPosition>,
        usedDominoes: inout Set<String>,
        result: inout [PlacedDomino]
    ) -> Bool {
        guard let firstEmpty = sortedCells.first(where: { !coveredCells.contains($0) }) else {
            return validateAllConstraints(puzzle: puzzle, cellValues: cellValues)
        }

        let neighbors = (adjacency[firstEmpty] ?? []).filter { !coveredCells.contains($0) }
        if neighbors.isEmpty { return false }

        for neighbor in neighbors {
            for domino in puzzle.availableDominoes where !usedDominoes.contains(domino.id) {
                let orientations: [(Int, Int)] = domino.pip1 == domino.pip2
                    ? [(domino.pip1, domino.pip2)]
                    : [(domino.pip1, domino.pip2), (domino.pip2, domino.pip1)]

                for (val1, val2) in orientations {
                    cellValues[firstEmpty] = val1
                    cellValues[neighbor] = val2
                    coveredCells.insert(firstEmpty)
                    coveredCells.insert(neighbor)
                    usedDominoes.insert(domino.id)

                    let placed = PlacedDomino(
                        id: "\(domino.id)-\(firstEmpty.row)\(firstEmpty.col)",
                        domino: domino,
                        position1: firstEmpty,
                        position2: neighbor,
                        pip1Value: val1,
                        pip2Value: val2
                    )
                    result.append(placed)

                    if checkPartialConstraints(puzzle: puzzle, cellValues: cellValues) {
                        if backtrack(
                            puzzle: puzzle,
                            sortedCells: sortedCells,
                            adjacency: adjacency,
                            cellValues: &cellValues,
                            coveredCells: &coveredCells,
                            usedDominoes: &usedDominoes,
                            result: &result
                        ) {
                            return true
                        }
                    }

                    result.removeLast()
                    cellValues.removeValue(forKey: firstEmpty)
                    cellValues.removeValue(forKey: neighbor)
                    coveredCells.remove(firstEmpty)
                    coveredCells.remove(neighbor)
                    usedDominoes.remove(domino.id)
                }
            }
        }
        return false
    }

    private func checkPartialConstraints(puzzle: Puzzle, cellValues: [GridPosition: Int]) -> Bool {
        for region in puzzle.regions {
            if !isConstraintSatisfied(region: region, cellValues: cellValues, partial: true) {
                return false
            }
        }
        return true
    }

    private func validateAllConstraints(puzzle: Puzzle, cellValues: [GridPosition: Int]) -> Bool {
        for region in puzzle.regions {
            if !isConstraintSatisfied(region: region, cellValues: cellValues, partial: false) {
                return false
            }
        }
        return true
    }

    private func isConstraintSatisfied(
        region: Region,
        cellValues: [GridPosition: Int],
        partial: Bool
    ) -> Bool {
        let filledCells = region.cells.filter { cellValues[$0] != nil }
        let values = filledCells.compactMap { cellValues[$0] }
        let allFilled = filledCells.count == region.cells.count

        if values.isEmpty { return true }

        switch region.constraint {
        case .none:
            return true

        case .equal:
            let allSame = values.allSatisfy { $0 == values[0] }
            if !allSame { return false }
            return partial || allFilled

        case .notEqual:
            let uniqueCount = Set(values).count
            if uniqueCount != values.count { return false }
            return true

        case .sum(let target):
            let sum = values.reduce(0, +)
            if partial {
                let remaining = region.cells.count - filledCells.count
                return sum <= target && sum + remaining * 6 >= target
            }
            return sum == target && allFilled

        case .greaterThan(let n):
            let sum = values.reduce(0, +)
            if partial {
                let remaining = region.cells.count - filledCells.count
                return sum + remaining * 6 > n
            }
            return allFilled && sum > n

        case .lessThan(let n):
            let sum = values.reduce(0, +)
            if partial {
                return sum < n
            }
            return allFilled && sum < n
        }
    }
}
