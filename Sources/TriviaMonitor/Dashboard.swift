import Foundation

class Dashboard: @unchecked Sendable {
    private let config: MonitorConfig
    private let fetcher: DataFetcher
    private var isRunning = true

    init(config: MonitorConfig) {
        self.config = config
        self.fetcher = DataFetcher(config: config)
    }

    func run() async {
        // Setup signal handling for graceful exit
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        signalSource.setEventHandler { [weak self] in
            self?.isRunning = false
        }
        signalSource.resume()

        // Hide cursor and clear screen
        print(ANSIRenderer.hideCursor(), terminator: "")

        while isRunning {
            // Fetch all data
            let state = await fetcher.fetchAll()

            // Render dashboard
            render(state: state)

            // Wait for refresh interval
            do {
                try await Task.sleep(nanoseconds: UInt64(config.refreshInterval) * 1_000_000_000)
            } catch {
                break
            }
        }

        signalSource.cancel()

        // Cleanup
        await cleanup()
    }

    private func render(state: DashboardState) {
        var output = ANSIRenderer.clearScreen()

        // Header
        output += ANSIRenderer.headerBox(title: "TRIVIA MONITOR")
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
