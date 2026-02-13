import SwiftUI

/// Completion menu view - displays candidate command list
///
/// This view shows a scrollable list of completion candidates
/// with their frequency counts. The selected item is highlighted.
struct CompletionMenuView: View {
    /// Observed completion state
    @ObservedObject var completionState: Ghostty.SurfaceView.CompletionState

    /// Cell size for proper font sizing
    let cellSize: CGSize

    /// Maximum menu height
    private let maxMenuHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(completionState.candidates.enumerated()), id: \.1.id) { index, candidate in
                CompletionMenuItem(
                    candidate: candidate,
                    isSelected: index == completionState.selectedIndex,
                    cellSize: cellSize
                )
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
        .frame(maxHeight: maxMenuHeight)
        .frame(maxWidth: 500)
    }
}

/// Individual completion menu item
struct CompletionMenuItem: View {
    /// The completion candidate
    let candidate: Ghostty.SurfaceView.CompletionCandidate

    /// Whether this item is selected
    let isSelected: Bool

    /// Cell size for proper font sizing
    let cellSize: CGSize

    var body: some View {
        HStack(spacing: 12) {
            // Command text
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.command)
                    .font(.system(size: cellSize.height * 0.85, design: .monospaced))
                    .foregroundColor(isSelected ? .primary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Frequency indicator
                if candidate.frequency > 0 {
                    Text("(\(candidate.frequency))")
                        .font(.system(size: cellSize.height * 0.6, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: cellSize.height * 0.5))
                    .foregroundColor(.accentColor)
                    .opacity(0.8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
        .cornerRadius(6)
    }
}

// Preview provider for SwiftUI canvas
struct CompletionMenuView_Previews: PreviewProvider {
    static var previews: some View {
        let mockState = Ghostty.SurfaceView.CompletionState(
            inputPrefix: "git",
            previewText: " push",
            candidates: [
                Ghostty.SurfaceView.CompletionCandidate(
                    command: "git push",
                    frequency: 45
                ),
                Ghostty.SurfaceView.CompletionCandidate(
                    command: "git pull",
                    frequency: 23
                ),
                Ghostty.SurfaceView.CompletionCandidate(
                    command: "git status",
                    frequency: 12
                ),
            ],
            selectedIndex: 0,
            isMenuVisible: true
        )

        CompletionMenuView(
            completionState: mockState,
            cellSize: CGSize(width: 10, height: 20)
        )
        .previewDisplayName("Completion Menu")
    }
}
