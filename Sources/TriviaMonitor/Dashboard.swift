import Foundation

class Dashboard: @unchecked Sendable {
    private let config: MonitorConfig
    private let fetcher: DataFetcher
    private let launcher: ProcessLauncher
    private let keyboard: KeyboardInput
    private var isRunning = true

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

        // Hide cursor and clear screen
        print(ANSIRenderer.hideCursor(), terminator: "")

        while isRunning {
            // Poll for keyboard input
            keyboard.poll()

            // Fetch all data
            let state = await fetcher.fetchAll()

            // Render dashboard
            render(state: state)

            // Wait for refresh interval (shorter for responsive keyboard)
            do {
                try await Task.sleep(nanoseconds: 200_000_000)  // 200ms for responsive input
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
        var output = ANSIRenderer.clearScreen()

        // Header with status message
        let statusMsg = launcher.getStatus()
        output += ANSIRenderer.headerBox(title: "TRIVIA MONITOR", statusMessage: statusMsg)
        output += "\n"

        // Server section
        output += Widgets.serverWidget(state: state, config: config)
        output += "\n"

        // Validation section
        output += Widgets.validationWidget(state: state)
        output += "\n"

        // Daemon section
        output += Widgets.daemonWidget(state: state)
        output += "\n"

        // Footer
        output += Widgets.footer(state: state, config: config)

        print(output, terminator: "")
        fflush(stdout)
    }

    private func cleanup() async {
        // Restore terminal
        keyboard.disable()

        // Show cursor and move to bottom
        print(ANSIRenderer.showCursor())
        print("\n" + ANSIRenderer.cyan("Monitor stopped."))

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
