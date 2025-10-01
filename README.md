# ZephyrOS Executor

Local AI task execution engine that polls ZMemory for tasks and executes them using Claude API.

## Quick Start

📚 **[Complete Setup Guide →](SETUP_GUIDE.md)**

### macOS App

```bash
# 1. Open in Xcode
cd "ZephyrOS Executor"
open "ZephyrOS Executor.xcodeproj"

# 2. Configure Google OAuth and environment variables
# See SETUP_GUIDE.md for detailed instructions

# 3. Build and Run (⌘R)
```

**First run:**
1. Sign in with Google
2. App connects to ZMemory using your OAuth token
3. Start executor from Dashboard

### Python CLI

```bash
pip install -r requirements.txt
cp .env.example .env  # Add your API keys
python main.py
```

📖 **Need help?** See [SETUP_GUIDE.md](SETUP_GUIDE.md) for troubleshooting

## Features

### macOS Native App
- ✅ **Google OAuth Login** - Sign in with your ZephyrOS account
- ✅ SwiftUI interface with native macOS design
- ✅ Dashboard with real-time status and statistics
- ✅ Task queue browser (search, filter, details)
- ✅ Execution logs viewer with filtering
- ✅ Settings management with persistence
- ✅ Menu bar integration with quick controls
- ✅ Background operation support
- ✅ User-specific task access via OAuth token

### Python CLI
- ✅ Terminal interface with colored output
- ✅ Multi-threaded task execution
- ✅ Real-time statistics display
- ✅ Portable (runs on any Python platform)
- ✅ Easy to automate/script

### Core Capabilities
- ✅ Polls ZMemory API for pending tasks
- ✅ Executes tasks using Claude API (Sonnet 4)
- ✅ Reports results back to ZMemory
- ✅ Configurable concurrency (1-10 tasks)
- ✅ Adjustable polling interval (10s-5m)
- ✅ Error handling and automatic retry
- ✅ Token usage tracking and cost estimation
- ✅ Task progress monitoring

## Architecture

```
┌─────────────┐     Poll      ┌──────────────┐
│   ZMemory   │ ←────────────  │   Executor   │
│   Backend   │                │   (Local)    │
└─────────────┘                └──────────────┘
       ↑                              │
       │ Report Results               │ Execute
       │                              ↓
       │                       ┌──────────────┐
       └───────────────────────│  Claude API  │
                               └──────────────┘
```

**Two Implementations:**
1. **macOS App**: SwiftUI + Combine + async/await
2. **Python CLI**: Threading + requests + colorama

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed design.

## Project Structure

```
ZephyrOS-Executor/
├── README.md                    # This file
├── SETUP.md                     # Setup instructions
├── ARCHITECTURE.md              # System architecture
├── LICENSE
│
├── ZephyrOS Executor/           # macOS App (SwiftUI)
│   ├── ZephyrOS Executor/
│   │   ├── ZephyrOSExecutorApp.swift
│   │   ├── Models/              # Data models
│   │   ├── Services/            # API clients, managers
│   │   └── Views/               # SwiftUI views
│   └── ZephyrOS Executor.xcodeproj
│
├── src/                         # Python CLI
│   ├── cli.py                   # Terminal interface
│   ├── executor.py              # Task executor
│   ├── zmemory_client.py        # ZMemory API
│   ├── claude_client.py         # Claude API
│   └── config.py                # Configuration
│
├── main.py                      # Python CLI entry point
├── requirements.txt             # Python dependencies
├── mock_zmemory_server.py       # Mock server for testing
└── zephyros-executor-design.md  # Original design doc
```

## Configuration

### macOS App
Configure via Settings tab in the app:
- ZMemory API URL and key
- Anthropic API key
- Agent name and parameters

Settings persist in UserDefaults.

### Python CLI
Configure via `.env` file:
```bash
ZMEMORY_API_URL=http://localhost:5000
ZMEMORY_API_KEY=test-key-12345
ANTHROPIC_API_KEY=sk-ant-...
AGENT_NAME=executor-1
MAX_CONCURRENT_TASKS=2
POLLING_INTERVAL_SECONDS=30
```

## Local Testing

Use the included mock server:

```bash
# Terminal 1: Start mock ZMemory server
python mock_zmemory_server.py

# Terminal 2: Run executor
# Configure to use http://localhost:5000
# Watch tasks execute!
```

The mock server creates sample tasks that demonstrate the full workflow.

## Development

### macOS App
```bash
cd "ZephyrOS Executor"
open "ZephyrOS Executor.xcodeproj"
# Edit files in Xcode
# Build: ⌘B, Run: ⌘R
```

**Files to modify:**
- `Models/` - Data structures
- `Services/` - Business logic and API clients
- `Views/` - UI components

### Python CLI
```bash
# Edit files in src/
python main.py  # Test changes
```

**Files to modify:**
- `src/executor.py` - Core execution logic
- `src/cli.py` - Terminal interface
- `src/*_client.py` - API clients

See [SETUP.md](SETUP.md) for detailed development setup.

## Use Cases

### Desktop Users → macOS App
- Visual task monitoring
- Easy configuration via GUI
- Menu bar quick access
- Native macOS experience

### Servers/Automation → Python CLI
- Headless operation
- Easy to deploy
- Scriptable configuration
- Low resource usage

### Development/Testing → Either + Mock Server
- Test locally without backend
- Iterate quickly
- Debug full workflow

## Requirements

- **macOS App**: macOS 13.0+, Xcode 15.0+
- **Python CLI**: Python 3.8+
- **Both**: Anthropic API key

## Documentation

- **[SETUP.md](SETUP.md)** - Installation and setup
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design and architecture
- **[zephyros-executor-design.md](zephyros-executor-design.md)** - Original design document

## Status

- ✅ macOS App: Built, tested, fully functional
- ✅ Python CLI: Built, tested, fully functional
- ✅ Mock Server: Working, ready for testing
- ⏳ Production ZMemory backend: TBD

## License

MIT

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

See [ARCHITECTURE.md](ARCHITECTURE.md) for extension points.
