import SwiftUI

struct DominoTrayView: View {
    let dominoes: [Domino]
    let usedIDs: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DOMINOES")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(dominoes) { domino in
                        DominoTileView(
                            domino: domino,
                            isUsed: usedIDs.contains(domino.id)
                        )
                    }
                }
            }
            .contentMargins(.horizontal, 16)
            .scrollIndicators(.hidden)
        }
    }
}

struct DominoTileView: View {
    let domino: Domino
    let isUsed: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            PipDotsView(
                value: domino.pip1,
                size: 28,
                dotColor: isUsed ? .secondary.opacity(0.3) : (colorScheme == .dark ? .white : Color(white: 0.15))
            )
            .frame(width: 32, height: 32)

            Rectangle()
                .fill(isUsed ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.3))
                .frame(width: 1, height: 20)

            PipDotsView(
                value: domino.pip2,
                size: 28,
                dotColor: isUsed ? .secondary.opacity(0.3) : (colorScheme == .dark ? .white : Color(white: 0.15))
            )
            .frame(width: 32, height: 32)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isUsed
                      ? Color(.tertiarySystemBackground).opacity(0.5)
                      : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isUsed ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .opacity(isUsed ? 0.5 : 1.0)
    }
}
