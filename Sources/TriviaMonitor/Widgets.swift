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

            // Summary stats line
            let total = daemon.totalFetched
            let successRate = total > 0 ? Double(daemon.questionsAdded) / Double(total) * 100 : 0
            let rateStr = String(format: "%.1f%%", successRate)

            let line2 = "Total Fetched: \(ANSIRenderer.cyan(String(total)))    " +
                       "Success Rate: \(ANSIRenderer.green(rateStr))    " +
                       "Errors: \(daemon.errors > 0 ? ANSIRenderer.red(String(daemon.errors)) : "0")"
            output += ANSIRenderer.row(line2)

            output += ANSIRenderer.sectionMiddle()

            // Breakdown with progress bars
            let addedPct = total > 0 ? Int(Double(daemon.questionsAdded) / Double(total) * 100) : 0
            let dupsPct = total > 0 ? Int(Double(daemon.duplicatesSkipped) / Double(total) * 100) : 0

            let addedBar = ANSIRenderer.progressBar(value: daemon.questionsAdded, total: total, width: 20)
            let dupsBar = ANSIRenderer.progressBar(value: daemon.duplicatesSkipped, total: total, width: 20)

            let addedLine = ANSIRenderer.padRight("Added:", to: 12) +
                           String(format: "%6d", daemon.questionsAdded) + " " + addedBar +
                           String(format: " %3d%%", addedPct)
            output += ANSIRenderer.row(addedLine)

            let dupsLine = ANSIRenderer.padRight("Duplicates:", to: 12) +
                          String(format: "%6d", daemon.duplicatesSkipped) + " " + dupsBar +
                          String(format: " %3d%%", dupsPct)
            output += ANSIRenderer.row(dupsLine)

            // Provider status
            if !daemon.providers.isEmpty {
                output += ANSIRenderer.sectionMiddle()
                output += ANSIRenderer.row(ANSIRenderer.cyan("Providers:"))

                for provider in daemon.providers {
                    let dot = ANSIRenderer.providerDot(enabled: provider.enabled)
                    let status = provider.enabled ? ANSIRenderer.green("active") : ANSIRenderer.gray("off")
                    let countStr: String
                    if let count = provider.questionsAdded {
                        countStr = "  (\(count) added)"
                    } else {
                        countStr = ""
                    }
                    let line = "  \(dot) \(ANSIRenderer.padRight(provider.name, to: 14)) \(status)\(countStr)"
                    output += ANSIRenderer.row(line)
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
        let webLink = ANSIRenderer.hyperlink("Open Web App", url: config.webFrontendURL, color: .cyan)

        return ANSIRenderer.gray("─── Refresh: \(refreshStr) │ Last: \(timeStr) │ [W] ") +
               webLink +
               ANSIRenderer.gray(" ─────────────") + "\n"
    }
}
