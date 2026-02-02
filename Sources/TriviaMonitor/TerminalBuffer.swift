import Foundation

/// Double-buffered terminal output - redraws entire screen each time for clean display
class TerminalBuffer {
    private var previousLineCount = 0

    /// Render content with full screen clear to avoid ghost lines
    func render(_ lines: [String]) {
        // Move cursor to home position
        print("\u{001B}[H", terminator: "")

        // Render all lines, clearing each line first
        for (index, line) in lines.enumerated() {
            // Move to line, clear it, print content
            print("\u{001B}[\(index + 1);1H\u{001B}[2K\(line)", terminator: "")
        }

        // Clear any remaining lines from previous render
        if lines.count < previousLineCount {
            for i in lines.count..<previousLineCount {
                print("\u{001B}[\(i + 1);1H\u{001B}[2K", terminator: "")
            }
        }

        // Move cursor below content
        print("\u{001B}[\(lines.count + 1);1H", terminator: "")
        fflush(stdout)

        previousLineCount = lines.count
    }

    /// Force a full redraw on next render
    func invalidate() {
        previousLineCount = 0
    }

    /// Clear screen completely
    func clear() {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        fflush(stdout)
        previousLineCount = 0
    }
}
