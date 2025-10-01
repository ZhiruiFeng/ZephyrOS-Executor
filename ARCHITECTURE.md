# Architecture

## Overview

ZephyrOS Executor is a local agent that polls ZMemory for AI tasks and executes them using Claude API. Available in two implementations:

- **macOS App**: Native SwiftUI application with full GUI
- **Python CLI**: Terminal-based executor for servers/testing

Both share the same architecture pattern but different technology stacks.

## High-Level Architecture

```
┌─────────────┐      Poll       ┌──────────────┐
│   ZMemory   │ ←──────────────  │   Executor   │
│   Backend   │                  │   (Local)    │
└─────────────┘                  └──────────────┘
                                        │
                                        │ Execute
                                        ↓
                                 ┌──────────────┐
                                 │  Claude API  │
                                 │  (Anthropic) │
                                 └──────────────┘
```

**Flow:**
1. Executor polls ZMemory for pending tasks (every 30s)
2. Accepts and downloads task details
3. Sends task to Claude API for execution
4. Receives response from Claude
5. Reports results back to ZMemory

## macOS App Architecture

### Technology Stack
- **UI**: SwiftUI (native macOS)
- **State Management**: Combine framework (@Published, ObservableObject)
- **Networking**: URLSession with async/await
- **Storage**: UserDefaults (config), in-memory (runtime state)
- **Menu Bar**: AppKit integration

### Component Structure

```
┌─────────────────────────────────────────────┐
│              SwiftUI Views                  │
│  ┌────────────┐  ┌────────────────────┐   │
│  │ Dashboard  │  │  Tasks  │  Logs    │   │
│  └────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────┘
                    ↕ @EnvironmentObject
┌─────────────────────────────────────────────┐
│         ExecutorManager (Singleton)         │
│         @Published state & stats            │
└─────────────────────────────────────────────┘
                    ↕
┌──────────────────┐      ┌─────────────────┐
│ ZMemoryClient    │      │  ClaudeClient   │
│ (REST API)       │      │  (Anthropic)    │
└──────────────────┘      └─────────────────┘
```

### Key Classes

**ExecutorManager** (Singleton)
- Central state manager
- Orchestrates polling and execution
- Observable by all views
- Manages API clients lifecycle

**ZMemoryClient**
- REST API wrapper for ZMemory
- Methods: getPendingTasks, acceptTask, updateStatus, completeTask

**ClaudeClient**
- Anthropic API wrapper
- Async task execution
- Token counting and cost tracking

**MenuBarManager**
- System tray integration
- Quick actions (start/stop/pause)
- Status indicators

### Data Models

**Task**
```swift
struct Task: Identifiable, Codable {
    let id: String
    var description: String
    var status: TaskStatus
    var progress: Int
    var result: TaskResult?
    // Computed properties: statusColor, statusIcon
}
```

**ExecutorState**
```swift
struct ExecutorState {
    var status: ExecutorStatus  // idle, running, paused, error
    var isConnectedToZMemory: Bool
    var isConnectedToClaude: Bool
    var activeTasks: [Task]
    var queuedTasks: [Task]
}
```

### Reactive Data Flow

```
User Action (Button Click)
    ↓
View calls ExecutorManager method
    ↓
ExecutorManager updates @Published properties
    ↓
SwiftUI automatically re-renders affected views
```

## Python CLI Architecture

### Technology Stack
- **Language**: Python 3.8+
- **HTTP**: requests library
- **CLI**: colorama for colored output
- **Async**: threading for concurrent execution
- **Config**: python-dotenv

### Component Structure

```
┌─────────────┐
│    CLI      │  ← Terminal UI
└─────────────┘
       ↕
┌─────────────┐
│  Executor   │  ← Task execution engine
└─────────────┘
   ↕        ↕
┌────────┐  ┌──────────┐
│ZMemory │  │  Claude  │
│ Client │  │  Client  │
└────────┘  └──────────┘
```

### Key Modules

**executor.py**
- TaskExecutor class
- Polling loop (background thread)
- Task queue management
- Error handling and retries

**cli.py**
- ExecutorCLI class
- Colored terminal output
- Statistics display
- Signal handling (Ctrl+C)

**zmemory_client.py**
- ZMemoryClient class
- REST API methods
- Session management

**claude_client.py**
- ClaudeClient class
- Anthropic API integration
- Prompt building

## Concurrency Model

### macOS App
- **Main Thread**: UI updates only
- **Background Threads**:
  - Polling timer (30s intervals)
  - Task execution (_Concurrency.Task for async/await)
  - API calls (URLSession with async/await)

### Python CLI
- **Main Thread**: CLI event loop
- **Background Threads**:
  - Polling thread (30s intervals)
  - Executor threads (configurable, default 2)

## State Management

### macOS App
```swift
@StateObject var executorManager = ExecutorManager.shared
```
- Single source of truth
- All views observe ExecutorManager
- Changes propagate via Combine framework

### Python CLI
```python
class TaskExecutor:
    def __init__(self):
        self.running = False
        self.task_queue = Queue()
        self.active_tasks = {}
```
- Shared state via class properties
- Thread-safe with Queue and locks
- Statistics updated atomically

## API Integration

### ZMemory API Endpoints

```
GET  /health                  → Health check
GET  /tasks/pending           → Fetch pending tasks
POST /tasks/{id}/accept       → Accept task
PATCH /tasks/{id}/status      → Update progress
POST /tasks/{id}/complete     → Submit results
POST /tasks/{id}/fail         → Report failure
```

### Claude API

```
POST /v1/messages
Headers:
  x-api-key: {api_key}
  anthropic-version: 2023-06-01
Body:
  model: claude-sonnet-4-20250514
  max_tokens: 4096
  messages: [{ role: "user", content: "..." }]
```

## Error Handling

### Network Errors
- Retry with exponential backoff
- Max 3 retries per request
- Log errors and continue

### Task Failures
- Report to ZMemory with error details
- Continue processing other tasks
- Update statistics

### API Rate Limits
- Queue tasks locally
- Respect retry-after headers
- Graceful degradation

## Security

### API Keys
- **macOS**: Stored in UserDefaults (consider Keychain for production)
- **Python**: Environment variables (.env file)
- Never logged or exposed in UI

### Network
- HTTPS/TLS 1.3 for all API calls
- Certificate validation enabled
- No local server exposure

## Performance

### Resource Usage
- **macOS App**: ~50-100 MB RAM, <5% CPU idle
- **Python CLI**: ~30-50 MB RAM, <3% CPU idle

### Scalability
- Max concurrent tasks: Configurable (default 2)
- Polling interval: Configurable (default 30s)
- Token tracking: Per-task and cumulative

## Extension Points

### Adding New Task Types
1. Update Task model with new status/type
2. Add handler in executor
3. Update UI for new task display

### Custom API Backends
1. Implement client interface
2. Swap in ExecutorManager/TaskExecutor
3. Update configuration

### UI Customization (macOS)
1. Views are SwiftUI - easy to modify
2. Colors defined in models
3. Layout adjustable via modifiers

## Deployment

### macOS App
- Build via Xcode
- Archive for distribution
- Sign with Developer ID
- Notarize for macOS 14+

### Python CLI
- Package with PyInstaller
- Distribute as standalone binary
- Or pip install from repo

## Testing

### Mock Server
`mock_zmemory_server.py` simulates ZMemory backend:
- Creates random sample tasks
- Accepts task status updates
- Stores results in memory
- Perfect for local development

### Integration Testing
1. Start mock server
2. Run executor (macOS or Python)
3. Watch tasks flow through system
4. Verify results in logs

## Future Enhancements

### Planned Features
- [ ] CoreData persistence (task history)
- [ ] Advanced retry strategies
- [ ] Task scheduling/cron
- [ ] Multi-agent coordination
- [ ] Performance metrics dashboard
- [ ] Export capabilities

### Architectural Improvements
- [ ] Plugin system for task handlers
- [ ] Event streaming (vs polling)
- [ ] Distributed execution
- [ ] Local LLM support

## Comparison: macOS vs Python

| Feature | macOS App | Python CLI |
|---------|-----------|------------|
| UI | Native SwiftUI GUI | Terminal/colored text |
| Platform | macOS only | Cross-platform |
| Integration | Menu bar, notifications | Systemd, cron |
| State | In-memory + UserDefaults | In-memory |
| Best For | Desktop users | Servers, automation |
| Resource | ~100 MB | ~50 MB |

Choose macOS app for desktop use with GUI. Choose Python CLI for servers or automation.
