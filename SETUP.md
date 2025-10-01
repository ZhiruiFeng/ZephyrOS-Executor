# Setup Guide

**📚 Complete setup instructions have been consolidated into [SETUP_GUIDE.md](SETUP_GUIDE.md)**

This includes:
- Google OAuth configuration
- Xcode setup (URL schemes, environment variables)
- Building and running the app
- Troubleshooting common issues

For the old Python CLI setup, see the legacy instructions below.

---

## Legacy: Python CLI Setup

If you want to use the Python command-line version instead of the macOS app:

### Prerequisites
- Python 3.8+
- pip

### Installation

```bash
# Install dependencies
pip install -r requirements.txt

# Configure
cp .env.example .env
# Edit .env with your API keys

# Run
python main.py
```

### Configuration

Edit `.env` file:
```bash
ZMEMORY_API_URL=http://localhost:5000
ZMEMORY_API_KEY=test-key-12345
ANTHROPIC_API_KEY=sk-ant-your-key
AGENT_NAME=zephyr-executor-1
MAX_CONCURRENT_TASKS=2
POLLING_INTERVAL_SECONDS=30
```

### Testing with Mock Server

```bash
# Terminal 1: Start mock ZMemory server
python mock_zmemory_server.py

# Terminal 2: Run executor
python main.py
```

---

## macOS App

For the native macOS app with GUI and Google OAuth:

👉 **See [SETUP_GUIDE.md](SETUP_GUIDE.md) for complete instructions**
