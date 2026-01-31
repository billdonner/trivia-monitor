# Trivia Monitor

Real-time terminal dashboard for monitoring the trivia ecosystem services.

## Build & Run

```bash
# Development
swift run TriviaMonitor

# With options
swift run TriviaMonitor --server http://localhost:8080 --api-key xxx --refresh 5
```

## Global Installation

Install to `~/bin` for system-wide access:

```bash
swift build -c release
cp .build/release/TriviaMonitor ~/bin/

# Then run from anywhere:
TriviaMonitor
```

Note: `~/bin` is added to PATH in `~/.zshrc`.

## Data Sources

- **Server Health**: `GET {server}/health`
- **Validation Stats**: `GET {server}/api/v1/admin/validate/stats`
- **Daemon Stats**: File read from `/tmp/trivia-gen-daemon.stats.json`

## Architecture

- `main.swift` - Entry point, argument parsing
- `MonitorConfig.swift` - Configuration (URLs, API key, refresh interval)
- `DataFetcher.swift` - HTTP polling + file reading
- `Models.swift` - ValidationStats, DaemonStats
- `ANSIRenderer.swift` - Terminal colors, cursor control, box drawing
- `Widgets.swift` - Server, Validation, Daemon display widgets
- `Dashboard.swift` - Main render loop

## Key Shortcuts

- `S` - Start all trivia components (trivia-ill server, trivia-gen-daemon)
- `Q` - Quit monitor
- `Ctrl+C` - Exit (alternative)
