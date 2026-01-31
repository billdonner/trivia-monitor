import ArgumentParser
import Foundation

@main
struct TriviaMonitor: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "TriviaMonitor",
        abstract: "Real-time terminal dashboard for monitoring trivia ecosystem services",
        version: "1.0.0"
    )

    @Option(name: [.short, .long], help: "Server URL (default: http://localhost:8080)")
    var server: String = "http://localhost:8080"

    @Option(name: [.short, .long], help: "API key for authenticated endpoints")
    var apiKey: String = "trivia-admin-key-2024"

    @Option(name: [.short, .long], help: "Refresh interval in seconds (default: 3)")
    var refresh: Int = 3

    @Option(name: [.short, .long], help: "Path to daemon stats file")
    var daemonStats: String = "/tmp/trivia-gen-daemon.stats.json"

    @Option(name: [.long], help: "Base path to trivia projects (default: ~/trivial)")
    var triviaPath: String = "~/trivial"

    mutating func run() async throws {
        let config = MonitorConfig(
            serverURL: server,
            apiKey: apiKey,
            refreshInterval: refresh,
            daemonStatsPath: daemonStats,
            triviaBasePath: triviaPath
        )

        let dashboard = Dashboard(config: config)
        await dashboard.run()
    }
}
