import SwiftUI
import PhotosUI

@Observable
@MainActor
class PuzzleViewModel {
    var puzzle: Puzzle?
    var solution: [PlacedDomino]?
    var solveMode: SolveMode = .fullSolve
    var revealedStepCount: Int = 0
    var revealedCells: Set<GridPosition> = []
    var isExtracting: Bool = false
    var isSolving: Bool = false
    var errorMessage: String?
    var selectedImage: UIImage?
    var selectedPhotoItem: PhotosPickerItem?
    var hasSolved: Bool = false

    var visibleDominoes: [PlacedDomino] {
        guard let solution else { return [] }
        guard hasSolved else { return [] }
        switch solveMode {
        case .fullSolve:
            return solution
        case .stepThrough:
            return Array(solution.prefix(revealedStepCount))
        case .hint:
            return solution.filter {
                revealedCells.contains($0.position1) || revealedCells.contains($0.position2)
            }
        }
    }

    var cellValues: [GridPosition: Int] {
        var values: [GridPosition: Int] = [:]
        for placed in visibleDominoes {
            values[placed.position1] = placed.pip1Value
            values[placed.position2] = placed.pip2Value
        }
        return values
    }

    var usedDominoIDs: Set<String> {
        Set(visibleDominoes.map(\.domino.id))
    }

    var canStepForward: Bool {
        guard let solution else { return false }
        return revealedStepCount < solution.count
    }

    var isSolutionComplete: Bool {
        guard let solution else { return false }
        return visibleDominoes.count == solution.count
    }

    func loadImage(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = "Could not load the selected image."
            return
        }
        selectedImage = image
        puzzle = nil
        solution = nil
        hasSolved = false
        revealedStepCount = 0
        revealedCells = []
        await extractPuzzle(from: image)
    }

    func extractPuzzle(from image: UIImage) async {
        let toolkitURL = Config.EXPO_PUBLIC_TOOLKIT_URL
        guard !toolkitURL.isEmpty else {
            errorMessage = ExtractionError.noToolkitURL.localizedDescription
            return
        }

        isExtracting = true
        errorMessage = nil

        do {
            let service = VisionExtractionService(toolkitURL: toolkitURL)
            let extracted = try await service.extractPuzzle(from: image)
            puzzle = extracted
        } catch {
            errorMessage = error.localizedDescription
        }

        isExtracting = false
    }

    func solvePuzzle() async {
        guard let puzzle else { return }
        isSolving = true
        errorMessage = nil
        hasSolved = false
        revealedStepCount = 0
        revealedCells = []

        let solver = PuzzleSolver()
        let puzzleCopy = puzzle

        let result = await Task.detached(priority: .userInitiated) {
            solver.solve(puzzleCopy)
        }.value

        if let result {
            solution = result
            hasSolved = true
            if solveMode == .stepThrough {
                revealedStepCount = 0
            }
        } else {
            errorMessage = "No solution found. The puzzle data may be incorrect."
        }

        isSolving = false
    }

    func nextStep() {
        guard let solution, revealedStepCount < solution.count else { return }
        revealedStepCount += 1
    }

    func previousStep() {
        guard revealedStepCount > 0 else { return }
        revealedStepCount -= 1
    }

    func revealHint(at position: GridPosition) {
        guard solution != nil else { return }
        revealedCells.insert(position)
    }

    func resetSolution() {
        hasSolved = false
        revealedStepCount = 0
        revealedCells = []
    }

    func clearPuzzle() {
        puzzle = nil
        solution = nil
        selectedImage = nil
        hasSolved = false
        revealedStepCount = 0
        revealedCells = []
        errorMessage = nil
    }
}
