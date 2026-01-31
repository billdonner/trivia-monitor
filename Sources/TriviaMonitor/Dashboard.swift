import Foundation

class Dashboard: @unchecked Sendable {
    private let config: MonitorConfig
    private let fetcher: DataFetcher
    private let launcher: ProcessLauncher
    private let keyboard: KeyboardInput
    private let terminalBuffer: TerminalBuffer
    private var isRunning = true
    private var forceRefresh = false
    private var monitorStats = MonitorStats()

    init(config: MonitorConfig) {
        self.config = config
        self.fetcher = DataFetcher(config: config)
        self.launcher = ProcessLauncher(triviaBasePath: config.triviaBasePath)
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
        case "s":
            startAllComponents()
        case "r":
            forceRefresh = true
            launcher.setStatus("Refreshing...", duration: 1)
        case "q":
            isRunning = false
        default:
            break
        }
    }

    private func startAllComponents() {
        let result = launcher.startAllComponents()

        var message: String
        if result.started > 0 && result.failed == 0 {
            message = "Started \(result.started) component(s)"
            if result.alreadyRunning > 0 {
                message += ", \(result.alreadyRunning) already running"
            }
        } else if result.alreadyRunning > 0 && result.started == 0 && result.failed == 0 {
            message = "All \(result.alreadyRunning) component(s) already running"
        } else if result.failed > 0 {
            message = "Started \(result.started), failed \(result.failed)"
        } else {
            message = "No components to start"
        }

        launcher.setStatus(message, duration: 5)
    }

    private func render(state: DashboardState) {
        // Build complete output first
        var lines: [String] = []

        // Header with status message
        let statusMsg = launcher.getStatus()
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
