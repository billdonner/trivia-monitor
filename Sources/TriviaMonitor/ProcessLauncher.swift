import Foundation

/// Manages launching and checking status of trivia ecosystem processes
class ProcessLauncher {
    private let triviaBasePath: String
    private var launchedProcesses: [String: Process] = [:]
    private var statusMessage: String?
    private var statusExpiry: Date?

    init(triviaBasePath: String = "~/trivial") {
        self.triviaBasePath = NSString(string: triviaBasePath).expandingTildeInPath
    }

    // MARK: - Process Definitions

    struct ComponentDef {
        let name: String
        let directory: String
        let command: String
        let args: [String]
        let checkPort: Int?
        let checkFile: String?
    }

    var components: [ComponentDef] {
        [
            ComponentDef(
                name: "trivia-ill",
                directory: "\(triviaBasePath)/trivia-ill",
                command: "swift",
                args: ["run", "App", "serve"],
                checkPort: 8080,
                checkFile: nil
            ),
            ComponentDef(
                name: "trivia-gen-daemon",
                directory: "\(triviaBasePath)/trivia-gen-daemon",
                command: "swift",
                args: ["run", "TriviaGen"],
                checkPort: nil,
                checkFile: "/tmp/trivia-gen-daemon.stats.json"
            ),
        ]
    }

    // MARK: - Status Checking

    func isServerRunning(port: Int) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-i", ":\(port)", "-sTCP:LISTEN"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    func isDaemonRunning() -> Bool {
        // Check if stats file was updated recently (within last 2 minutes)
        let statsPath = "/tmp/trivia-gen-daemon.stats.json"
        let fileManager = FileManager.default

        guard let attrs = try? fileManager.attributesOfItem(atPath: statsPath),
              let modDate = attrs[.modificationDate] as? Date else {
            return false
        }

        return Date().timeIntervalSince(modDate) < 120
    }

    func getComponentStatus() -> [(ComponentDef, Bool)] {
        components.map { component in
            let running: Bool
            if let port = component.checkPort {
                running = isServerRunning(port: port)
            } else if component.checkFile != nil {
                running = isDaemonRunning()
            } else {
                running = false
            }
            return (component, running)
        }
    }

    // MARK: - Process Launching

    func startComponent(_ component: ComponentDef) -> Bool {
        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: component.directory)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [component.command] + component.args

        // Redirect output to /dev/null or log files
        let logPath = "/tmp/\(component.name).log"
        if let logHandle = FileHandle(forWritingAtPath: logPath) {
            process.standardOutput = logHandle
            process.standardError = logHandle
        } else {
            FileManager.default.createFile(atPath: logPath, contents: nil)
            if let logHandle = FileHandle(forWritingAtPath: logPath) {
                process.standardOutput = logHandle
                process.standardError = logHandle
            } else {
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
            }
        }

        do {
            try process.run()
            launchedProcesses[component.name] = process
            return true
        } catch {
            return false
        }
    }

    func startAllComponents() -> (started: Int, alreadyRunning: Int, failed: Int) {
        var started = 0
        var alreadyRunning = 0
        var failed = 0

        for (component, isRunning) in getComponentStatus() {
            if isRunning {
                alreadyRunning += 1
            } else if startComponent(component) {
                started += 1
            } else {
                failed += 1
            }
        }

        return (started, alreadyRunning, failed)
    }

    // MARK: - Status Message

    func setStatus(_ message: String, duration: TimeInterval = 5) {
        statusMessage = message
        statusExpiry = Date().addingTimeInterval(duration)
    }

    func getStatus() -> String? {
        guard let expiry = statusExpiry, Date() < expiry else {
            statusMessage = nil
            statusExpiry = nil
            return nil
        }
        return statusMessage
    }

    // MARK: - Cleanup

    func cleanup() {
        for (_, process) in launchedProcesses {
            if process.isRunning {
                process.terminate()
            }
        }
        launchedProcesses.removeAll()
    }
}
