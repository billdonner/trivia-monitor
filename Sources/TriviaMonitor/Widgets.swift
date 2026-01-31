import Foundation

struct Widgets {

    // MARK: - Server Widget

    static func serverWidget(state: DashboardState, config: MonitorConfig) -> String {
        var output = ANSIRenderer.sectionTop(title: "SERVER (trivia-ill)")

        let statusText = state.serverOnline ? ANSIRenderer.green("ONLINE") : ANSIRenderer.red("OFFLINE")
        let dot = ANSIRenderer.statusDot(online: state.serverOnline)

        // Extract host from URL
        let url = config.serverURL.replacingOccurrences(of: "http://", with: "")
                                   .replacingOccurrences(of: "https://", with: "")

        let line1 = "Status: \(dot) \(statusText)        URL: \(url)"
        output += ANSIRenderer.row(line1)

        if let error = state.serverError, !state.serverOnline {
            let errorLine = ANSIRenderer.red("Error: \(String(error.prefix(50)))...")
            output += ANSIRenderer.row(errorLine)
        }

        // Monitor performance stats (compact)
        output += ANSIRenderer.sectionMiddle()

        let stats = state.monitorStats
        let latencyStr = String(format: "%.0fms", stats.lastLatencyMs)
        let uptimeStr = ANSIRenderer.formatUptime(stats.monitorUptime)
        let successRateStr = String(format: "%.0f%%", stats.successRate)

        let line2 = "Polls: \(ANSIRenderer.cyan(String(stats.pollCount)))  " +
                   "Latency: \(ANSIRenderer.cyan(latencyStr))  " +
                   "Uptime: \(ANSIRenderer.cyan(uptimeStr))  " +
                   "OK: \(ANSIRenderer.green(successRateStr))"
        output += ANSIRenderer.row(line2)

        output += ANSIRenderer.sectionBottom()
        return output
    }

    // MARK: - Validation Widget

    static func validationWidget(state: DashboardState) -> String {
        var output = ANSIRenderer.sectionTop(title: "VALIDATION")

        if let stats = state.validationStats {
            // First row: Queue stats
            let line1 = "Queue: \(ANSIRenderer.cyan(String(stats.queueSize)))    " +
                       "Processing: \(ANSIRenderer.cyan(String(stats.processing)))    " +
                       "Pending: \(ANSIRenderer.yellow(String(stats.pending)))    " +
                       "Approved: \(ANSIRenderer.green(String(stats.approved)))"
            output += ANSIRenderer.row(line1)

            // Second row: Flagged/Rejected
            let line2 = "Flagged: \(ANSIRenderer.yellow(String(stats.flagged)))  " +
                       "Rejected: \(ANSIRenderer.red(String(stats.rejected)))"
            output += ANSIRenderer.row(line2)

            // Worker stats with progress bars
            if !stats.workerStats.isEmpty {
                output += ANSIRenderer.sectionMiddle()

                let total = stats.workerStats.values.reduce(0, +)
                let sortedWorkers = stats.workerStats.sorted { $0.value > $1.value }

                for (name, count) in sortedWorkers.prefix(4) {
                    let percentage = total > 0 ? Int(Double(count) / Double(total) * 100) : 0
                    let bar = ANSIRenderer.progressBar(value: count, total: total)
                    let paddedName = ANSIRenderer.padRight("\(name):", to: 18)
                    let paddedCount = String(format: "%4d", count)
                    let line = "\(paddedName) \(paddedCount) \(bar) \(String(format: "%3d", percentage))%"
                    output += ANSIRenderer.row(line)
                }
            }
        } else {
            let errorMsg = state.validationError ?? "No data available"
            output += ANSIRenderer.row(ANSIRenderer.gray("Waiting for data..."))
            if state.serverOnline {
                output += ANSIRenderer.row(ANSIRenderer.yellow(String(errorMsg.prefix(55))))
            }
        }

        output += ANSIRenderer.sectionBottom()
        return output
    }

    // MARK: - Daemon Widget

    static func daemonWidget(state: DashboardState) -> String {
        var output = ANSIRenderer.sectionTop(title: "GEN DAEMON")

        if let daemon = state.daemonStats {
            // Status line
            let stateText: String
            switch daemon.state.lowercased() {
            case "running": stateText = ANSIRenderer.green("RUNNING")
            case "paused": stateText = ANSIRenderer.yellow("PAUSED")
            case "stopped": stateText = ANSIRenderer.red("STOPPED")
            default: stateText = ANSIRenderer.gray(daemon.state.uppercased())
            }

            let dot = ANSIRenderer.statusDot(state: daemon.state)
            let startTimeStr = ANSIRenderer.formatStartTime(daemon.startTime)
            let runtime = ANSIRenderer.formatRuntime(from: daemon.startTime)

            let line1 = "Status: \(dot) \(stateText)       Started: \(startTimeStr)        Runtime: \(runtime)"
            output += ANSIRenderer.row(line1)

            output += ANSIRenderer.sectionMiddle()

            // Stats line
            let fetchedStr = ANSIRenderer.cyan(String(daemon.totalFetched))
            let addedStr = ANSIRenderer.green(String(daemon.questionsAdded))
            let dupsStr = ANSIRenderer.yellow(String(daemon.duplicatesSkipped))
            let errorsStr = daemon.errors > 0 ? ANSIRenderer.red(String(daemon.errors)) : String(daemon.errors)

            let line2 = "Fetched: \(fetchedStr)   Added: \(addedStr)   Duplicates: \(dupsStr)   Errors: \(errorsStr)"
            output += ANSIRenderer.row(line2)

            // Provider status (3 per row max)
            if !daemon.providers.isEmpty {
                output += ANSIRenderer.sectionMiddle()

                // First row: up to 3 providers
                var line1 = ""
                for (index, provider) in daemon.providers.prefix(3).enumerated() {
                    let dot = ANSIRenderer.providerDot(enabled: provider.enabled)
                    let status = provider.enabled ? "on" : "off"
                    let name = String(provider.name.prefix(10))
                    line1 += "\(dot) \(name) [\(status)]"
                    if index < 2 && index < daemon.providers.count - 1 {
                        line1 += "  "
                    }
                }
                output += ANSIRenderer.row(line1)

                // Second row if more than 3 providers
                if daemon.providers.count > 3 {
                    var line2 = ""
                    for (index, provider) in daemon.providers.dropFirst(3).prefix(3).enumerated() {
                        let dot = ANSIRenderer.providerDot(enabled: provider.enabled)
                        let status = provider.enabled ? "on" : "off"
                        let name = String(provider.name.prefix(10))
                        line2 += "\(dot) \(name) [\(status)]"
                        if index < 2 && index < daemon.providers.count - 4 {
                            line2 += "  "
                        }
                    }
                    output += ANSIRenderer.row(line2)
                }
            }
        } else {
            output += ANSIRenderer.row(ANSIRenderer.gray("Daemon not running or stats file not found"))
            if let error = state.daemonError {
                output += ANSIRenderer.row(ANSIRenderer.yellow(String(error.prefix(55))))
            }
        }

        output += ANSIRenderer.sectionBottom()
        return output
    }

    // MARK: - Footer

    static func footer(state: DashboardState, config: MonitorConfig) -> String {
        let timeStr = ANSIRenderer.formatTime(state.lastUpdate)
        let refreshStr = "\(config.refreshInterval)s"

        return ANSIRenderer.gray("─── Refresh: \(refreshStr) │ Last: \(timeStr) ") +
               ANSIRenderer.gray(String(repeating: "─", count: 40)) + "\n"
    }
}
