import SwiftUI
import GhosttyKit

/// Completion preview view - displays gray inline completion suggestion
///
/// This view shows the completion preview text in gray color,
/// positioned after the cursor. It provides a visual hint of what
/// would be completed if the user presses Tab.
struct CompletionPreviewView: View {
    /// The completion state containing preview data
    let completionState: Ghostty.SurfaceView.CompletionState?

    /// Cell size for proper font sizing
    let cellSize: CGSize

    var body: some View {
        if let state = completionState,
           !state.previewText.isEmpty,
           !state.inputPrefix.isEmpty {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // User input prefix (invisible, for layout)
                    Text(state.inputPrefix)
                        .foregroundColor(.clear)
                        .font(.system(size: cellSize.height * 0.9, design: .monospaced))

                    // Completion preview (gray/dimmed)
                    Text(state.previewText)
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.system(size: cellSize.height * 0.9, design: .monospaced))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, cellSize.width * 0.2)
                .padding(.trailing, cellSize.width * 0.1)
            }
            .allowsHitTesting(false)
        }
    }
}
