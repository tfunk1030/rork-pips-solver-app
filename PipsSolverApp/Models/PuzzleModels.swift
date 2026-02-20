import SwiftUI

nonisolated struct GridPosition: Hashable, Sendable, Codable {
    let row: Int
    let col: Int

    var neighbors: [GridPosition] {
        [
            GridPosition(row: row - 1, col: col),
            GridPosition(row: row + 1, col: col),
            GridPosition(row: row, col: col - 1),
            GridPosition(row: row, col: col + 1)
        ]
    }
}

nonisolated enum ConstraintType: Hashable, Sendable {
    case sum(Int)
    case equal
    case notEqual
    case greaterThan(Int)
    case lessThan(Int)
    case none

    var displayText: String {
        switch self {
        case .sum(let n): return "\(n)"
        case .equal: return "="
        case .notEqual: return "\u{2260}"
        case .greaterThan(let n): return ">\(n)"
        case .lessThan(let n): return "<\(n)"
        case .none: return ""
        }
    }

    var hasConstraint: Bool {
        if case .none = self { return false }
        return true
    }
}

nonisolated struct Region: Identifiable, Sendable {
    let id: String
    let cells: Set<GridPosition>
    let constraint: ConstraintType
    let colorIndex: Int

    var centerCell: GridPosition {
        let avgRow = Double(cells.map(\.row).reduce(0, +)) / Double(cells.count)
        let avgCol = Double(cells.map(\.col).reduce(0, +)) / Double(cells.count)
        return cells.min(by: {
            let d1 = pow(Double($0.row) - avgRow, 2) + pow(Double($0.col) - avgCol, 2)
            let d2 = pow(Double($1.row) - avgRow, 2) + pow(Double($1.col) - avgCol, 2)
            return d1 < d2
        }) ?? cells.first!
    }
}

nonisolated struct Domino: Identifiable, Hashable, Sendable {
    let id: String
    let pip1: Int
    let pip2: Int

    var label: String {
        "\(pip1)|\(pip2)"
    }
}

nonisolated struct PlacedDomino: Identifiable, Sendable, Hashable {
    let id: String
    let domino: Domino
    let position1: GridPosition
    let position2: GridPosition
    let pip1Value: Int
    let pip2Value: Int
}

nonisolated struct Puzzle: Sendable {
    let rows: Int
    let cols: Int
    let activeCells: Set<GridPosition>
    let cellRegionMap: [GridPosition: String]
    let regions: [Region]
    let availableDominoes: [Domino]

    func regionFor(cell: GridPosition) -> Region? {
        guard let regionId = cellRegionMap[cell] else { return nil }
        return regions.first { $0.id == regionId }
    }
}

nonisolated enum SolveMode: String, CaseIterable, Sendable {
    case fullSolve = "Full Solve"
    case hint = "Hint"
    case stepThrough = "Step-by-Step"
}

nonisolated enum RegionColors {
    static let palette: [Color] = [
        Color(red: 0.91, green: 0.45, blue: 0.43),
        Color(red: 0.42, green: 0.72, blue: 0.91),
        Color(red: 0.52, green: 0.82, blue: 0.48),
        Color(red: 0.95, green: 0.75, blue: 0.35),
        Color(red: 0.68, green: 0.50, blue: 0.85),
        Color(red: 0.92, green: 0.55, blue: 0.68),
        Color(red: 0.35, green: 0.78, blue: 0.72),
        Color(red: 0.85, green: 0.68, blue: 0.48),
        Color(red: 0.58, green: 0.58, blue: 0.88),
        Color(red: 0.72, green: 0.87, blue: 0.45),
    ]

    static func color(for index: Int) -> Color {
        palette[index % palette.count]
    }
}

nonisolated struct ExtractionResponse: Codable, Sendable {
    let rows: Int
    let cols: Int
    let cells: [CellData]
    let regions: [RegionData]
    let dominoes: [DominoData]
}

nonisolated struct CellData: Codable, Sendable {
    let row: Int
    let col: Int
    let regionId: String
}

nonisolated struct RegionData: Codable, Sendable {
    let id: String
    let constraintType: String
    let constraintValue: Int?
}

nonisolated struct DominoData: Codable, Sendable {
    let pip1: Int
    let pip2: Int
}
