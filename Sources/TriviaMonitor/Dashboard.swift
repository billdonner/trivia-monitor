import Foundation

class Dashboard: @unchecked Sendable {
    private let config: MonitorConfig
    private let fetcher: DataFetcher
    private let launcher: ProcessLauncher
    private let keyboard: KeyboardInput
    private var isRunning = true
    private var monitorStats = MonitorStats()

    init(config: MonitorConfig) {
        self.config = config
        self.fetcher = DataFetcher(config: config)
        self.launcher = ProcessLauncher(triviaBasePath: config.triviaBasePath)
        self.keyboard = KeyboardInput()
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

            // Only fetch and render at the configured refresh interval
            let now = Date()
            if now.timeIntervalSince(lastRender) >= refreshInterval {
                // Fetch all data
                var state = await fetcher.fetchAll(existingStats: monitorStats)

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
        lines.append("")

        // Validation section
        lines.append(contentsOf: Widgets.validationWidget(state: state).components(separatedBy: "\n"))
        lines.append("")

        // Daemon section
        lines.append(contentsOf: Widgets.daemonWidget(state: state).components(separatedBy: "\n"))
        lines.append("")

        // Footer
        lines.append(contentsOf: Widgets.footer(state: state, config: config).components(separatedBy: "\n"))

        // Clear screen, move home, then print each line
        var output = "\u{001B}[2J\u{001B}[H"
        for line in lines {
            output += line + "\n"
        }

        // Write all at once using Darwin write for atomic output
        output.withCString { ptr in
            _ = Darwin.write(STDOUT_FILENO, ptr, strlen(ptr))
        }
    }

    private func cleanup() async {
        // Restore terminal
        keyboard.disable()

        // Show cursor
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
