# Setup Guide

## Prerequisites

- macOS 13.0+
- Xcode 15.0+
- Python 3.8+ (for CLI version or testing)

## Quick Setup

### Option 1: macOS App (Native GUI)

The Xcode project is already set up in `ZephyrOS Executor/`.

**Run the app:**
```bash
cd "ZephyrOS Executor"
open "ZephyrOS Executor.xcodeproj"
# Press ⌘R in Xcode
```

**Configure on first launch:**
1. Go to Settings tab
2. Enter:
   - ZMemory API URL: `http://localhost:5000` (for testing)
   - ZMemory API Key: `test-key-12345` (for testing)
   - Anthropic API Key: `sk-ant-your-actual-key`
3. Click "Save Configuration"
4. Go to Dashboard → Click "Start"

### Option 2: Python CLI (Terminal)

**Install dependencies:**
```bash
pip install -r requirements.txt
```

**Configure:**
```bash
cp .env.example .env
# Edit .env with your API keys
```

**Run:**
```bash
python main.py
```

## Local Testing

Use the mock ZMemory server for testing without a real backend:

**Terminal 1 - Start mock server:**
```bash
python mock_zmemory_server.py
```

**Terminal 2 - Run executor:**
- macOS app: Configure with `http://localhost:5000` in Settings
- Python CLI: Set `ZMEMORY_API_URL=http://localhost:5000` in `.env`

The mock server creates sample AI tasks that the executor will pick up and execute using Claude.

## Development Setup

### Building from Source (macOS App)

The project structure:
```
ZephyrOS Executor/
├── ZephyrOS Executor/          # Source code
│   ├── ZephyrOSExecutorApp.swift
│   ├── Models/
│   ├── Services/
│   └── Views/
└── ZephyrOS Executor.xcodeproj # Xcode project
```

**Clean build:**
```bash
cd "ZephyrOS Executor"
xcodebuild clean
xcodebuild -scheme "ZephyrOS Executor" build
```

### Modifying the Python CLI

Edit files in `src/`:
- `cli.py` - Terminal interface
- `executor.py` - Task execution logic
- `zmemory_client.py` - ZMemory API
- `claude_client.py` - Claude API

## Configuration

### macOS App
Settings are stored in UserDefaults. Configure via the Settings tab in the app.

### Python CLI
Settings in `.env` file:
```
ZMEMORY_API_URL=http://localhost:5000
ZMEMORY_API_KEY=test-key
ANTHROPIC_API_KEY=sk-ant-...
AGENT_NAME=executor-1
MAX_CONCURRENT_TASKS=2
POLLING_INTERVAL_SECONDS=30
```

## Troubleshooting

### macOS App won't build
```bash
cd "ZephyrOS Executor"
xcodebuild clean
# Reopen Xcode
```

### Python CLI errors
```bash
pip install -r requirements.txt --upgrade
python -m pytest  # If tests exist
```

### Can't connect to ZMemory
- Ensure mock server is running: `python mock_zmemory_server.py`
- Check URL in config: `http://localhost:5000`
- Verify API key matches mock server

### Claude API errors
- Verify API key is valid: `sk-ant-...`
- Check API credits at console.anthropic.com
- Review logs for specific error messages

## Next Steps

- See [ARCHITECTURE.md](ARCHITECTURE.md) for system design
- See [README.md](README.md) for feature overview
- Original design: [zephyros-executor-design.md](zephyros-executor-design.md)
