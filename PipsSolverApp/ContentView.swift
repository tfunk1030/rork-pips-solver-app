import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var viewModel = PuzzleViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if let puzzle = viewModel.puzzle {
                    puzzleSolveView(puzzle: puzzle)
                } else {
                    ImportView(
                        selectedItem: $viewModel.selectedPhotoItem,
                        isExtracting: viewModel.isExtracting
                    )
                }
            }
            .navigationTitle("Pips Solver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.puzzle != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.clearPuzzle()
                        } label: {
                            Label("New", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .onChange(of: viewModel.selectedPhotoItem) { _, newValue in
                if let item = newValue {
                    Task {
                        await viewModel.loadImage(from: item)
                        viewModel.selectedPhotoItem = nil
                    }
                }
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                if let msg = viewModel.errorMessage {
                    Text(msg)
                }
            }
        }
    }

    @ViewBuilder
    private func puzzleSolveView(puzzle: Puzzle) -> some View {
        VStack(spacing: 0) {
            puzzleInfoBar(puzzle: puzzle)

            Picker("Mode", selection: $viewModel.solveMode) {
                ForEach(SolveMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .onChange(of: viewModel.solveMode) { _, _ in
                viewModel.resetSolution()
            }

            PuzzleGridView(
                puzzle: puzzle,
                cellValues: viewModel.cellValues,
                visibleDominoes: viewModel.visibleDominoes,
                solveMode: viewModel.solveMode,
                onCellTap: { position in
                    if viewModel.solveMode == .hint && viewModel.hasSolved {
                        viewModel.revealHint(at: position)
                    }
                }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            solveControls

            DominoTrayView(
                dominoes: puzzle.availableDominoes,
                usedIDs: viewModel.usedDominoIDs
            )
            .padding(.bottom, 8)
        }
    }

    private func puzzleInfoBar(puzzle: Puzzle) -> some View {
        HStack(spacing: 16) {
            Label("\(puzzle.rows)\u{00D7}\(puzzle.cols)", systemImage: "square.grid.3x3")
                .font(.caption)
                .foregroundStyle(.secondary)

            Label("\(puzzle.regions.count) regions", systemImage: "square.stack.3d.up")
                .font(.caption)
                .foregroundStyle(.secondary)

            Label("\(puzzle.availableDominoes.count) dominoes", systemImage: "rectangle.split.2x1")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground).opacity(0.5))
    }

    @ViewBuilder
    private var solveControls: some View {
        VStack(spacing: 8) {
            if viewModel.isSolving {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Solving...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if !viewModel.hasSolved {
                Button {
                    Task { await viewModel.solvePuzzle() }
                } label: {
                    Label("Solve Puzzle", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 16)
            } else {
                switch viewModel.solveMode {
                case .fullSolve:
                    if viewModel.isSolutionComplete {
                        Label("Solved!", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.vertical, 8)
                    }

                case .stepThrough:
                    HStack(spacing: 16) {
                        Button {
                            viewModel.previousStep()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.revealedStepCount == 0)

                        Text("\(viewModel.revealedStepCount) / \(viewModel.solution?.count ?? 0)")
                            .font(.headline.monospacedDigit())
                            .frame(minWidth: 60)

                        Button {
                            viewModel.nextStep()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title3.weight(.semibold))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canStepForward)
                    }
                    .padding(.vertical, 4)

                case .hint:
                    Text("Tap any empty cell to reveal its domino")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
