import SwiftUI
import GhosttyKit

/// Completion preview view - displays gray inline completion suggestion
///
/// This view shows the completion preview text in gray color,
/// positioned at the cursor location. It provides a visual hint of what
/// would be completed if the user presses Tab.
struct CompletionPreviewView: View {
    /// Observed completion state
    @ObservedObject var completionState: Ghostty.SurfaceView.CompletionState

    /// Cell size for proper font sizing
    let cellSize: CGSize

    /// The surface pointer for getting cursor position
    let surface: ghostty_surface_t

    var body: some View {
        // Use a computed property that forces view refresh when data changes
        let previewValue = completionState.previewText
        let prefixValue = completionState.inputPrefix

        if !previewValue.isEmpty && !prefixValue.isEmpty {
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

                    // HStack for completion text and Tab hint
                    HStack(spacing: 4) {
                        // Completion preview text
                        Text(previewValue)
                            .foregroundColor(.secondary.opacity(0.5))
                            .font(.system(size: cellSize.height * 0.9, design: .monospaced))
                            // Force view refresh when previewText changes
                            .id("preview-\(previewValue)-\(prefixValue)")

                        // Tab key hint with icon
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.right.to.line.alt")
                                .font(.system(size: cellSize.height * 0.5))
                            Text("Tab")
                                .font(.system(size: cellSize.height * 0.6, design: .monospaced))
                        }
                        .foregroundColor(.secondary.opacity(0.3))
                        .padding(.leading, 4)
                    }
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
