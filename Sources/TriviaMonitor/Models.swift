import Foundation

// MARK: - Server Health

struct ServerHealth: Codable {
    let status: String
    let uptime: Double?
    let version: String?

    var isOnline: Bool {
        status.lowercased() == "ok" || status.lowercased() == "healthy"
    }
}

// MARK: - Validation Stats

struct ValidationStats: Codable {
    let queueSize: Int
    let processing: Int
    let pending: Int
    let approved: Int
    let flagged: Int
    let rejected: Int
    let workerStats: [String: Int]

    init(
        queueSize: Int = 0,
        processing: Int = 0,
        pending: Int = 0,
        approved: Int = 0,
        flagged: Int = 0,
        rejected: Int = 0,
        workerStats: [String: Int] = [:]
    ) {
        self.queueSize = queueSize
        self.processing = processing
        self.pending = pending
        self.approved = approved
        self.flagged = flagged
        self.rejected = rejected
        self.workerStats = workerStats
    }
}

// MARK: - Daemon Stats

struct ProviderStatus: Codable {
    let name: String
    let enabled: Bool
    let questionsAdded: Int?

    init(name: String, enabled: Bool, questionsAdded: Int? = nil) {
        self.name = name
        self.enabled = enabled
        self.questionsAdded = questionsAdded
    }
}

struct DaemonStats: Codable {
    let state: String
    let startTime: Date?
    let totalFetched: Int
    let questionsAdded: Int
    let duplicatesSkipped: Int
    let errors: Int
    let providers: [ProviderStatus]

    init(
        state: String = "unknown",
        startTime: Date? = nil,
        totalFetched: Int = 0,
        questionsAdded: Int = 0,
        duplicatesSkipped: Int = 0,
        errors: Int = 0,
        providers: [ProviderStatus] = []
    ) {
        self.state = state
        self.startTime = startTime
        self.totalFetched = totalFetched
        self.questionsAdded = questionsAdded
        self.duplicatesSkipped = duplicatesSkipped
        self.errors = errors
        self.providers = providers
    }

    var isRunning: Bool {
        state.lowercased() == "running"
    }

    var isPaused: Bool {
        state.lowercased() == "paused"
    }
}

// MARK: - Dashboard State

struct DashboardState {
    var serverOnline: Bool = false
    var serverHealth: ServerHealth?
    var serverUptime: String = "--"
    var validationStats: ValidationStats?
    var daemonStats: DaemonStats?
    var lastUpdate: Date = Date()
    var serverError: String?
    var validationError: String?
    var daemonError: String?
}
