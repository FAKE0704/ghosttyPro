import SwiftUI
import GhosttyKit

/// Completion preview view - displays gray inline completion suggestion
///
/// This view shows the completion preview text in gray color,
/// positioned at the cursor location. It provides a visual hint of what
/// would be completed if the user presses Tab.
struct CompletionPreviewView: View {
    /// The completion state containing preview data
    let completionState: Ghostty.SurfaceView.CompletionState?

    /// Cell size for proper font sizing
    let cellSize: CGSize

    /// The surface pointer for getting cursor position
    let surface: ghostty_surface_t

    var body: some View {
        if let state = completionState,
           !state.previewText.isEmpty,
           !state.inputPrefix.isEmpty {
            GeometryReader { geometry in
                // Get cursor position from surface
                let cursorPos = getCursorPosition()

                // Calculate position based on cursor location
                let textHeight = cellSize.height * 0.9
                let xOffset = cursorPos.minX + cursorPos.width
                let yOffset = cursorPos.minY - textHeight

                ZStack(alignment: .topLeading) {
                    // Empty view for positioning
                    Color.clear
                        .frame(width: 1, height: 1)

                    // Completion preview text
                    Text(state.previewText)
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.system(size: cellSize.height * 0.9, design: .monospaced))
                        .offset(x: xOffset, y: yOffset)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            }
            .allowsHitTesting(false)
        }
    }

    /// Get cursor position from the terminal surface
    private func getCursorPosition() -> CGRect {
        var x: Double = 0
        var y: Double = 0
        var width: Double = 0
        var height: Double = 0

        ghostty_surface_ime_point(surface, &x, &y, &width, &height)

        return CGRect(x: x, y: y, width: width, height: max(height, cellSize.height))
    }
}
