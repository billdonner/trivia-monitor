# Terminal Monitor Dashboard Specification

A reusable pattern for building real-time CLI monitoring dashboards in Swift.

---

## Overview

A standalone CLI tool that displays a real-time terminal dashboard monitoring services, processes, or any data sources. Uses ANSI escape codes for colors and cursor control, with double-buffered rendering to minimize flicker.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     main.swift                               │
│              (CLI entry, argument parsing)                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                    Dashboard.swift                           │
│         (Main loop: fetch → render → sleep)                  │
└───────┬─────────────┬─────────────┬─────────────────────────┘
        │             │             │
┌───────▼───────┐ ┌───▼───────┐ ┌───▼─────────────┐
│ DataFetcher   │ │ Widgets   │ │ TerminalBuffer  │
│ (HTTP/File)   │ │ (UI)      │ │ (Rendering)     │
└───────────────┘ └───────────┘ └─────────────────┘
```

---

## File Structure Template

```
~/projects/my-monitor/
├── Package.swift
├── CLAUDE.md
└── Sources/MyMonitor/
    ├── main.swift              # Entry point, argument parsing
    ├── MonitorConfig.swift     # Configuration struct
    ├── DataFetcher.swift       # Data collection (HTTP, files, etc.)
    ├── Models.swift            # Data models for your domain
    ├── ANSIRenderer.swift      # Terminal colors and box drawing
    ├── TerminalBuffer.swift    # Double-buffered rendering
    ├── Widgets.swift           # UI sections/widgets
    ├── Dashboard.swift         # Main render loop
    ├── KeyboardInput.swift     # Non-blocking keyboard handling
    └── ProcessLauncher.swift   # Optional: start/stop services
```

---

## Package.swift Template

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MyMonitor",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.19.0"),
    ],
    targets: [
        .executableTarget(
            name: "MyMonitor",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
    ]
)
```

---

## Core Components

### 1. ANSIRenderer (Terminal Control)

Provides ANSI escape sequences for:
- **Colors**: green, red, yellow, cyan, gray
- **Cursor**: hide, show, move to position
- **Screen**: clear screen
- **Box drawing**: Unicode box characters (┌ ─ ┐ │ └ ┘ ├ ┤)

```swift
struct ANSIRenderer {
    static let width = 65  // Dashboard width in columns

    // Colors
    static func green(_ text: String) -> String { "\u{001B}[32m\(text)\u{001B}[0m" }
    static func red(_ text: String) -> String { "\u{001B}[31m\(text)\u{001B}[0m" }
    static func yellow(_ text: String) -> String { "\u{001B}[33m\(text)\u{001B}[0m" }
    static func cyan(_ text: String) -> String { "\u{001B}[36m\(text)\u{001B}[0m" }
    static func gray(_ text: String) -> String { "\u{001B}[90m\(text)\u{001B}[0m" }

    // Cursor/Screen
    static func hideCursor() -> String { "\u{001B}[?25l" }
    static func showCursor() -> String { "\u{001B}[?25h" }
    static func clearScreen() -> String { "\u{001B}[2J\u{001B}[H" }
    static func moveTo(row: Int, col: Int) -> String { "\u{001B}[\(row);\(col)H" }
    static func clearLine() -> String { "\u{001B}[2K" }

    // Box drawing helpers
    static func sectionTop(title: String) -> String { ... }
    static func sectionMiddle() -> String { ... }
    static func sectionBottom() -> String { ... }
    static func row(_ content: String) -> String { ... }

    // Progress bar
    static func progressBar(value: Int, total: Int, width: Int = 22) -> String { ... }

    // Status indicators
    static func statusDot(online: Bool) -> String { online ? green("●") : red("●") }
}
```

### 2. TerminalBuffer (Double-Buffered Rendering)

Only redraws lines that changed between updates:

```swift
class TerminalBuffer {
    private var previousLines: [String] = []
    private var isFirstRender = true

    func render(_ lines: [String]) {
        if isFirstRender {
            // Full clear and draw
            print("\u{001B}[2J\u{001B}[H", terminator: "")
            for line in lines { print(line) }
            fflush(stdout)
            previousLines = lines
            isFirstRender = false
            return
        }

        // Only update changed lines
        for i in 0..<max(previousLines.count, lines.count) {
            let oldLine = i < previousLines.count ? previousLines[i] : ""
            let newLine = i < lines.count ? lines[i] : ""
            if oldLine != newLine {
                print("\u{001B}[\(i + 1);1H\u{001B}[2K\(newLine)", terminator: "")
            }
        }
        fflush(stdout)
        previousLines = lines
    }
}
```

### 3. DataFetcher (Data Collection)

Collects data from various sources:

```swift
actor DataFetcher {
    private let httpClient: HTTPClient

    // HTTP endpoint
    func fetchFromAPI() async -> Result<MyData, Error> {
        var request = HTTPClientRequest(url: "http://localhost:8080/api/stats")
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        let response = try await httpClient.execute(request, timeout: .seconds(5))
        // Parse response...
    }

    // File-based stats
    func fetchFromFile() async -> Result<MyStats, Error> {
        let data = try Data(contentsOf: URL(fileURLWithPath: "/tmp/my-stats.json"))
        return try JSONDecoder().decode(MyStats.self, from: data)
    }

    // Fetch all sources in parallel
    func fetchAll() async -> DashboardState {
        async let api = fetchFromAPI()
        async let file = fetchFromFile()
        // Combine results...
    }
}
```

### 4. Widgets (UI Sections)

Each widget renders a section of the dashboard:

```swift
struct Widgets {
    static func serviceWidget(state: DashboardState) -> String {
        var output = ANSIRenderer.sectionTop(title: "MY SERVICE")

        let status = state.isOnline ? ANSIRenderer.green("ONLINE") : ANSIRenderer.red("OFFLINE")
        output += ANSIRenderer.row("Status: \(ANSIRenderer.statusDot(online: state.isOnline)) \(status)")
        output += ANSIRenderer.sectionMiddle()
        output += ANSIRenderer.row("Requests: \(state.requestCount)  Errors: \(state.errorCount)")
        output += ANSIRenderer.sectionBottom()

        return output
    }
}
```

### 5. Dashboard (Main Loop)

```swift
class Dashboard {
    private let config: MonitorConfig
    private let fetcher: DataFetcher
    private let terminalBuffer = TerminalBuffer()
    private var isRunning = true

    func run() async {
        // Setup signal handling (Ctrl+C)
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        signalSource.setEventHandler { self.isRunning = false }
        signalSource.resume()

        // Hide cursor
        print(ANSIRenderer.hideCursor(), terminator: "")
        fflush(stdout)

        var lastRender = Date.distantPast

        while isRunning {
            // Keyboard polling (if enabled)
            keyboard.poll()

            // Fetch and render at configured interval
            if Date().timeIntervalSince(lastRender) >= config.refreshInterval {
                let state = await fetcher.fetchAll()
                render(state: state)
                lastRender = Date()
            }

            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        }

        // Cleanup
        print(ANSIRenderer.showCursor())
    }

    private func render(state: DashboardState) {
        var lines: [String] = []
        lines.append(contentsOf: headerLines())
        lines.append(contentsOf: Widgets.serviceWidget(state: state).components(separatedBy: "\n"))
        lines.append(contentsOf: Widgets.statsWidget(state: state).components(separatedBy: "\n"))
        lines.append(contentsOf: footerLines())

        terminalBuffer.render(lines.filter { !$0.isEmpty })
    }
}
```

### 6. KeyboardInput (Optional)

Non-blocking keyboard input for interactive controls:

```swift
class KeyboardInput {
    private var originalTermios: termios?

    func enable(handler: @escaping (Character) -> Void) {
        var raw = termios()
        tcgetattr(STDIN_FILENO, &raw)
        originalTermios = raw
        raw.c_lflag &= ~(UInt(ECHO | ICANON))
        raw.c_cc.16 = 0  // VMIN
        raw.c_cc.17 = 0  // VTIME
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)

        let flags = fcntl(STDIN_FILENO, F_GETFL)
        fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK)
    }

    func poll() {
        var buffer: UInt8 = 0
        if read(STDIN_FILENO, &buffer, 1) == 1 {
            handler?(Character(UnicodeScalar(buffer)))
        }
    }

    func disable() {
        if var original = originalTermios {
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
        }
    }
}
```

---

## Data Sources

### HTTP Endpoints
```swift
// GET with auth header
var request = HTTPClientRequest(url: url)
request.headers.add(name: "X-API-Key", value: apiKey)
let response = try await httpClient.execute(request, timeout: .seconds(5))
```

### JSON Stats Files
For daemons/services, write stats to a JSON file:
```swift
// In your daemon:
func writeStatsFile() {
    let stats = MyStats(count: count, startTime: startTime, ...)
    let data = try JSONEncoder().encode(stats)
    try data.write(to: URL(fileURLWithPath: "/tmp/my-daemon.stats.json"))
}

// In monitor:
let data = try Data(contentsOf: URL(fileURLWithPath: "/tmp/my-daemon.stats.json"))
let stats = try JSONDecoder().decode(MyStats.self, from: data)
```

### Process Detection
```swift
func isProcessRunning(port: Int) -> Bool {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    task.arguments = ["-i", ":\(port)", "-sTCP:LISTEN"]
    try task.run()
    task.waitUntilExit()
    return task.terminationStatus == 0
}
```

---

## UI Layout Example

```
═══ MY MONITOR ═══                              [S:Start] [Q:Quit]
┌─ SERVICE NAME ──────────────────────────────────────────────────┐
│ Status: ● ONLINE        URL: localhost:8080                     │
├─────────────────────────────────────────────────────────────────┤
│ Requests: 1234   Errors: 5   Latency: 12ms                      │
└─────────────────────────────────────────────────────────────────┘
┌─ QUEUE STATUS ──────────────────────────────────────────────────┐
│ Pending: 45    Processing: 3    Completed: 892                  │
├─────────────────────────────────────────────────────────────────┤
│ worker_1:        450 ████████████░░░░░░░░░░  52%                │
│ worker_2:        312 ████████░░░░░░░░░░░░░░  36%                │
└─────────────────────────────────────────────────────────────────┘
┌─ BACKGROUND JOBS ───────────────────────────────────────────────┐
│ Status: ● RUNNING       Started: 10:30        Runtime: 2h15m    │
├─────────────────────────────────────────────────────────────────┤
│ Processed: 1500   Success: 1450   Failed: 50                    │
└─────────────────────────────────────────────────────────────────┘
─── Refresh: 3s │ Last: 12:45:32 ─────────────────────────────────
```

---

## CLI Options Template

```swift
@main
struct MyMonitor: AsyncParsableCommand {
    @Option(name: [.short, .long], help: "Server URL")
    var server: String = "http://localhost:8080"

    @Option(name: [.short, .long], help: "API key")
    var apiKey: String? = "default-key"

    @Option(name: [.short, .long], help: "Refresh interval in seconds")
    var refresh: Int = 3

    @Option(name: [.long], help: "Path to stats file")
    var statsFile: String = "/tmp/my-daemon.stats.json"

    mutating func run() async throws {
        let config = MonitorConfig(...)
        let dashboard = Dashboard(config: config)
        await dashboard.run()
    }
}
```

---

## Color Conventions

| Color  | Usage                              |
|--------|------------------------------------|
| Green  | Online, Success, Running, Approved |
| Red    | Offline, Error, Failed, Rejected   |
| Yellow | Warning, Pending, Flagged, Paused  |
| Cyan   | Labels, Counts, Headers            |
| Gray   | Disabled, Inactive, Hints          |

---

## Best Practices

1. **Refresh Rate**: 2-5 seconds is usually sufficient; faster causes unnecessary load
2. **Timeouts**: Set HTTP timeouts (5s) to prevent blocking
3. **Error Handling**: Show errors inline, don't crash on failed fetches
4. **Graceful Exit**: Handle SIGINT, restore cursor, cleanup resources
5. **Stats Files**: Use ISO8601 dates, pretty-print JSON for debugging
6. **Width**: Keep dashboard under 80 columns for compatibility
