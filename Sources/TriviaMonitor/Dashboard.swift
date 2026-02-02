import Foundation

class Dashboard: @unchecked Sendable {
    private let config: MonitorConfig
    private let fetcher: DataFetcher
    private let keyboard: KeyboardInput
    private let terminalBuffer: TerminalBuffer
    private var isRunning = true
    private var forceRefresh = false
    private var statusMessage: String?
    private var statusExpiry: Date?
    private var monitorStats = MonitorStats()

    init(config: MonitorConfig) {
        self.config = config
        self.fetcher = DataFetcher(config: config)
        self.keyboard = KeyboardInput()
        self.terminalBuffer = TerminalBuffer()
    }

    func run() async {
        // Setup signal handling for graceful exit
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        signalSource.setEventHandler { [weak self] in
            self?.isRunning = false
        }
        signalSource.resume()

        // Setup keyboard input
        keyboard.enable { [weak self] key in
            self?.handleKeyPress(key)
        }

        // Hide cursor
        print(ANSIRenderer.hideCursor(), terminator: "")
        fflush(stdout)

        var lastRender = Date.distantPast
        let refreshInterval = TimeInterval(config.refreshInterval)

        while isRunning {
            // Poll for keyboard input (non-blocking)
            keyboard.poll()

            // Only fetch and render at the configured refresh interval (or on force refresh)
            let now = Date()
            if now.timeIntervalSince(lastRender) >= refreshInterval || forceRefresh {
                forceRefresh = false
                // Fetch all data
                let state = await fetcher.fetchAll(existingStats: monitorStats)

                // Update our copy of monitor stats
                monitorStats = state.monitorStats

                // Render dashboard
                render(state: state)
                lastRender = now
            }

            // Short sleep for responsive keyboard without screen flicker
            do {
                try await Task.sleep(nanoseconds: 100_000_000)  // 100ms keyboard poll
            } catch {
                break
            }
        }

        signalSource.cancel()

        // Cleanup
        await cleanup()
    }

    private func handleKeyPress(_ key: Character) {
        switch key.lowercased() {
        case "r":
            forceRefresh = true
            setStatus("Refreshing...", duration: 1)
        case "w":
            openWebFrontend()
            setStatus("Opening web app...", duration: 2)
        case "q":
            isRunning = false
        default:
            break
        }
    }

    private func openWebFrontend() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [config.webFrontendURL]
        try? process.run()
    }

    private func setStatus(_ message: String, duration: TimeInterval) {
        statusMessage = message
        statusExpiry = Date().addingTimeInterval(duration)
    }

    private func getStatus() -> String? {
        guard let expiry = statusExpiry, Date() < expiry else {
            statusMessage = nil
            statusExpiry = nil
            return nil
        }
        return statusMessage
    }

    private func render(state: DashboardState) {
        // Build complete output first
        var lines: [String] = []

        // Header with status message
        let statusMsg = getStatus()
        lines.append(contentsOf: ANSIRenderer.headerBox(title: "TRIVIA MONITOR", statusMessage: statusMsg).components(separatedBy: "\n"))

        // Server section
        lines.append(contentsOf: Widgets.serverWidget(state: state, config: config).components(separatedBy: "\n"))

        // Validation section
        lines.append(contentsOf: Widgets.validationWidget(state: state).components(separatedBy: "\n"))

        // Daemon section
        lines.append(contentsOf: Widgets.daemonWidget(state: state).components(separatedBy: "\n"))

        // Footer
        lines.append(contentsOf: Widgets.footer(state: state, config: config).components(separatedBy: "\n"))

        // Filter empty lines and render with double-buffering
        let filteredLines = lines.filter { !$0.isEmpty }
        terminalBuffer.render(filteredLines)
    }

    private func cleanup() async {
        // Restore terminal
        keyboard.disable()

        // Clear and show cursor
        terminalBuffer.clear()
        print(ANSIRenderer.showCursor())
        print(ANSIRenderer.cyan("Monitor stopped."))

        do {
            try await fetcher.shutdown()
        } catch {
            // Ignore shutdown errors
        }
    }

    func stop() {
        isRunning = false
    }
}
