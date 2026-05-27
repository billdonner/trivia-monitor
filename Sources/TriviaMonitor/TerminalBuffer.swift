import Foundation
import Darwin

/// Simple terminal output - clears screen and redraws everything each time
class TerminalBuffer {
    private var isFirstRender = true

    /// Render content with full screen clear
    func render(_ lines: [String]) {
        // Use low-level write() which is more reliable in raw terminal mode
        let fd = STDOUT_FILENO

        // Clear screen and home cursor
        let clear = "\u{001B}[2J\u{001B}[H"
        _ = clear.withCString { ptr in
            Darwin.write(fd, ptr, strlen(ptr))
        }

        // Write each line
        for line in lines {
            let lineWithNewline = line + "\n"
            _ = lineWithNewline.withCString { ptr in
                Darwin.write(fd, ptr, strlen(ptr))
            }
        }
    }

    /// Force a full redraw on next render
    func invalidate() {
        isFirstRender = true
    }

    /// Clear screen completely
    func clear() {
        let clear = "\u{001B}[2J\u{001B}[H"
        _ = clear.withCString { ptr in
            Darwin.write(STDOUT_FILENO, ptr, strlen(ptr))
        }
    }
}
