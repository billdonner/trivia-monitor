import Foundation

struct MonitorConfig {
    let serverURL: String
    let apiKey: String
    let refreshInterval: Int
    let daemonStatsPath: String
    let triviaBasePath: String

    var healthURL: String {
        "\(serverURL)/health"
    }

    var validationStatsURL: String {
        "\(serverURL)/api/v1/admin/validate/stats"
    }

    init(
        serverURL: String = "http://localhost:8080",
        apiKey: String = "",
        refreshInterval: Int = 3,
        daemonStatsPath: String = "/tmp/trivia-gen-daemon.stats.json",
        triviaBasePath: String = "~/trivial"
    ) {
        self.serverURL = serverURL
        self.apiKey = apiKey
        self.refreshInterval = refreshInterval
        self.daemonStatsPath = daemonStatsPath
        self.triviaBasePath = triviaBasePath
    }
}
