import Foundation

enum ANSIColor: String {
    case reset = "\u{001B}[0m"
    case bold = "\u{001B}[1m"
    case dim = "\u{001B}[2m"

    case black = "\u{001B}[30m"
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"
    case white = "\u{001B}[37m"
    case gray = "\u{001B}[90m"

    case bgBlack = "\u{001B}[40m"
    case bgRed = "\u{001B}[41m"
    case bgGreen = "\u{001B}[42m"
    case bgYellow = "\u{001B}[43m"
    case bgBlue = "\u{001B}[44m"
}

struct ANSIRenderer {
    static let width = 65

    // MARK: - Cursor Control

    static func clearScreen() -> String {
        "\u{001B}[2J\u{001B}[H"
    }

    static func hideCursor() -> String {
        "\u{001B}[?25l"
    }

    static func showCursor() -> String {
        "\u{001B}[?25h"
    }

    static func moveTo(row: Int, col: Int) -> String {
        "\u{001B}[\(row);\(col)H"
    }

    static func clearToEnd() -> String {
        "\u{001B}[J"
    }

    static func clearLine() -> String {
        "\u{001B}[2K"
    }

    static func enterAltScreen() -> String {
        "\u{001B}[?1049h"
    }

    static func exitAltScreen() -> String {
        "\u{001B}[?1049l"
    }

    // MARK: - Colors

    static func color(_ text: String, _ color: ANSIColor) -> String {
        "\(color.rawValue)\(text)\(ANSIColor.reset.rawValue)"
    }

    static func green(_ text: String) -> String { color(text, .green) }
    static func yellow(_ text: String) -> String { color(text, .yellow) }
    static func red(_ text: String) -> String { color(text, .red) }
    static func cyan(_ text: String) -> String { color(text, .cyan) }
    static func gray(_ text: String) -> String { color(text, .gray) }
    static func bold(_ text: String) -> String { color(text, .bold) }

    // MARK: - Box Drawing

    static func headerBox(title: String, statusMessage: String? = nil) -> String {
        var result = ""

        // Single line header: ═══ TRIVIA MONITOR ═══ [R] [W] [S] [Q]
        let hint = "[R:Refresh] [W:Web] [S:Sim] [Q:Quit]"
        let titlePart = "═══ \(title) ═══"
        let spacing = width - titlePart.count - hint.count + 2
        result += cyan(titlePart) + String(repeating: " ", count: max(1, spacing)) + gray(hint) + "\n"

        // Show status message if present
        if let msg = statusMessage {
            result += yellow(msg) + "\n"
        }

        return result
    }

    static func sectionTop(title: String) -> String {
        let titlePart = " \(title) "
        let remaining = width - titlePart.count - 1
        return "┌─" + cyan(titlePart) + String(repeating: "─", count: remaining) + "┐\n"
    }

    static func sectionMiddle() -> String {
        "├" + String(repeating: "─", count: width) + "┤\n"
    }

    static func sectionBottom() -> String {
        "└" + String(repeating: "─", count: width) + "┘\n"
    }

    static func row(_ content: String) -> String {
        let stripped = stripANSI(content)
        let padding = max(1, width - stripped.count)
        return "│ " + content + String(repeating: " ", count: padding - 1) + "│\n"
    }

    // MARK: - Progress Bar

    static func progressBar(value: Int, total: Int, width barWidth: Int = 22) -> String {
        guard total > 0 else { return String(repeating: "░", count: barWidth) }
        let percentage = Double(value) / Double(total)
        let filled = Int(percentage * Double(barWidth))
        let empty = barWidth - filled
        return green(String(repeating: "█", count: filled)) + gray(String(repeating: "░", count: empty))
    }

    // MARK: - Status Indicators

    static func statusDot(online: Bool) -> String {
        online ? green("●") : red("●")
    }

    static func statusDot(state: String) -> String {
        switch state.lowercased() {
        case "running": return green("●")
        case "paused": return yellow("●")
        case "stopped", "error": return red("●")
        default: return gray("●")
        }
    }

    static func providerDot(enabled: Bool) -> String {
        enabled ? green("●") : gray("○")
    }

    // MARK: - Helpers

    static func stripANSI(_ text: String) -> String {
        // Remove ANSI escape sequences for length calculation
        let pattern = "\u{001B}\\[[0-9;]*m"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    static func padRight(_ text: String, to length: Int) -> String {
        let stripped = stripANSI(text)
        if stripped.count >= length {
            return text
        }
        return text + String(repeating: " ", count: length - stripped.count)
    }

    static func formatUptime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(Int(seconds))s"
        }
    }

    static func formatRuntime(from startTime: Date?) -> String {
        guard let start = startTime else { return "--" }
        let elapsed = Date().timeIntervalSince(start)
        return formatUptime(elapsed)
    }

    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    static func formatStartTime(_ date: Date?) -> String {
        guard let d = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: d)
    }

    // MARK: - Hyperlinks (OSC 8)

    /// Creates a clickable hyperlink using OSC 8 escape sequence
    /// Supported by iTerm2, Terminal.app (macOS Sonoma+), and other modern terminals
    static func hyperlink(_ text: String, url: String) -> String {
        "\u{001B}]8;;\(url)\u{0007}\(text)\u{001B}]8;;\u{0007}"
    }

    static func hyperlink(_ text: String, url: String, color: ANSIColor) -> String {
        "\u{001B}]8;;\(url)\u{0007}\(color.rawValue)\(text)\(ANSIColor.reset.rawValue)\u{001B}]8;;\u{0007}"
    }
}
