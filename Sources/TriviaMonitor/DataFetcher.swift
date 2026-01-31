import Foundation
import AsyncHTTPClient
import NIOCore

actor DataFetcher {
    private let config: MonitorConfig
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder

    init(config: MonitorConfig) {
        self.config = config
        self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    deinit {
        try? httpClient.syncShutdown()
    }

    func shutdown() async throws {
        try await httpClient.shutdown()
    }

    // MARK: - Server Health

    func fetchServerHealth() async -> Result<ServerHealth, Error> {
        do {
            var request = HTTPClientRequest(url: config.healthURL)
            request.method = .GET
            if let apiKey = config.apiKey {
                request.headers.add(name: "X-Admin-API-Key", value: apiKey)
            }

            let response = try await httpClient.execute(request, timeout: .seconds(5))
            let body = try await response.body.collect(upTo: 1024 * 1024)
            let data = Data(buffer: body)

            // Try parsing as JSON first
            if let health = try? decoder.decode(ServerHealth.self, from: data) {
                return .success(health)
            }

            // If plain text "ok" or similar
            if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return .success(ServerHealth(status: text, uptime: nil, version: nil))
            }

            return .success(ServerHealth(status: "ok", uptime: nil, version: nil))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Validation Stats

    func fetchValidationStats() async -> Result<ValidationStats, Error> {
        do {
            var request = HTTPClientRequest(url: config.validationStatsURL)
            request.method = .GET
            if let apiKey = config.apiKey {
                request.headers.add(name: "X-Admin-API-Key", value: apiKey)
            }

            let response = try await httpClient.execute(request, timeout: .seconds(5))
            let body = try await response.body.collect(upTo: 1024 * 1024)
            let data = Data(buffer: body)

            let stats = try decoder.decode(ValidationStats.self, from: data)
            return .success(stats)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Daemon Stats (File)

    func fetchDaemonStats() async -> Result<DaemonStats, Error> {
        do {
            let url = URL(fileURLWithPath: config.daemonStatsPath)
            let data = try Data(contentsOf: url)
            let stats = try decoder.decode(DaemonStats.self, from: data)
            return .success(stats)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Fetch All

    func fetchAll(existingStats: MonitorStats) async -> DashboardState {
        var state = DashboardState()
        state.lastUpdate = Date()
        state.monitorStats = existingStats

        let startTime = Date()

        // Fetch all in parallel
        async let healthResult = fetchServerHealth()
        async let validationResult = fetchValidationStats()
        async let daemonResult = fetchDaemonStats()

        // Process health
        switch await healthResult {
        case .success(let health):
            state.serverOnline = health.isOnline
            state.serverHealth = health
            if let uptime = health.uptime {
                state.serverUptime = ANSIRenderer.formatUptime(uptime)
            }
            let latencyMs = Date().timeIntervalSince(startTime) * 1000
            state.monitorStats.recordSuccess(latencyMs: latencyMs)
        case .failure(let error):
            state.serverOnline = false
            state.serverError = error.localizedDescription
            state.monitorStats.recordFailure()
        }

        // Process validation stats
        switch await validationResult {
        case .success(let stats):
            state.validationStats = stats
        case .failure(let error):
            state.validationError = error.localizedDescription
        }

        // Process daemon stats
        switch await daemonResult {
        case .success(let stats):
            state.daemonStats = stats
        case .failure(let error):
            state.daemonError = error.localizedDescription
        }

        return state
    }
}
