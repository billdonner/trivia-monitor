import Foundation

/// Double-buffered terminal output - only redraws lines that changed
class TerminalBuffer {
    private var previousLines: [String] = []
    private var isFirstRender = true

    /// Render new content, only updating lines that changed
    func render(_ lines: [String]) {
        if isFirstRender {
            // First render: clear screen and draw everything
            print("\u{001B}[2J\u{001B}[H", terminator: "")
            for line in lines {
                print(line)
            }
            fflush(stdout)
            previousLines = lines
            isFirstRender = false
            return
        }

        // Compare and update only changed lines
        let maxLines = max(previousLines.count, lines.count)

        for i in 0..<maxLines {
            let oldLine = i < previousLines.count ? previousLines[i] : ""
            let newLine = i < lines.count ? lines[i] : ""

            if oldLine != newLine {
                // Move cursor to line i+1 (1-indexed), column 1
                print("\u{001B}[\(i + 1);1H", terminator: "")
                // Clear the line
                print("\u{001B}[2K", terminator: "")
                // Print new content
                print(newLine, terminator: "")
            }
        }

        // Move cursor to bottom
        print("\u{001B}[\(lines.count + 1);1H", terminator: "")
        fflush(stdout)

        previousLines = lines
    }

    /// Force a full redraw on next render
    func invalidate() {
        isFirstRender = true
        previousLines = []
    }

    /// Clear screen completely
    func clear() {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        fflush(stdout)
        previousLines = []
        isFirstRender = true
    }
}
