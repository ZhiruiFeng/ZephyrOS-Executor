# ZephyrOS Local Executor - Design Document

## 1. Product Overview

**Name:** ZephyrOS Executor (or "Zephyr Runner")

**Tagline:** "Your local AI task execution engine"

**Purpose:** A native macOS application that continuously monitors ZMemory for AI tasks, automatically executes them using Claude, and reports results back to the cloud.

---

## 2. Design Philosophy

### Core Principles
- **Autonomous Operation:** Works in the background with minimal user intervention
- **Transparency:** Clear visibility into what's happening at all times
- **Reliability:** Robust error handling and retry mechanisms
- **Native Feel:** True macOS design language and behaviors
- **Resource Conscious:** Efficient resource usage with configurable limits

### Visual Direction
- Clean, modern macOS aesthetic
- Dark mode support (follows system preference)
- SF Pro font family
- Subtle animations and transitions
- Status-driven color system

---

## 3. Information Architecture

```
ZephyrOS Executor
│
├── Dashboard (Home)
│   ├── Status Overview
│   ├── Active Tasks
│   └── Quick Stats
│
├── Task Queue
│   ├── Pending Tasks
│   ├── In Progress Tasks
│   └── Completed Tasks
│
├── Execution Logs
│   ├── Real-time Console
│   ├── Task History
│   └── Error Reports
│
├── Settings
│   ├── Connection (ZMemory API)
│   ├── Claude Configuration
│   ├── Execution Limits
│   └── Notifications
│
└── Menu Bar Integration
    ├── Quick Status
    ├── Pause/Resume
    └── Recent Activity
```

---

## 4. User Interface Design

### 4.1 Menu Bar Icon

**States:**
- **Idle (Gray):** No active tasks, connected and waiting
- **Active (Blue, Pulsing):** Currently executing tasks
- **Error (Red):** Connection issues or task failures
- **Paused (Orange):** Executor is paused by user
- **Disconnected (Gray, Strikethrough):** Not connected to ZMemory

### 4.2 Main Window Layout

```
┌─────────────────────────────────────────────────────┐
│  ●  ●  ●                ZephyrOS Executor           │
├─────────────────────────────────────────────────────┤
│                                                     │
│  [Sidebar]                    [Main Content Area]  │
│  ┌──────────┐                                      │
│  │ 􀎟 Dashboard│  ┌────────────────────────────┐  │
│  │ 􀐱 Tasks    │  │   EXECUTOR STATUS          │  │
│  │ 􀉆 Logs     │  │   ● Running                │  │
│  │ ⚙️ Settings │  │   2 tasks in progress      │  │
│  └──────────┘  │                                │  │
│                 │   CURRENT TASKS               │  │
│                 │   ┌──────────────────────┐   │  │
│                 │   │ Refactor Auth Module │   │  │
│                 │   │ Progress: 45%        │   │  │
│                 │   │ ████████░░░░░░░░░░   │   │  │
│                 │   └──────────────────────┘   │  │
│                 │                                │  │
│                 │   STATISTICS (Today)          │  │
│                 │   Tasks: 12  Errors: 1       │  │
│                 │   API Cost: $2.34            │  │
│                 └────────────────────────────────┘  │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### 4.3 Dashboard View

**Components:**

1. **Status Card**
   - Current state indicator (large, prominent)
   - Connection status to ZMemory
   - Claude API health check
   - Last sync timestamp

2. **Active Tasks Panel**
   - Currently executing tasks (up to 3 displayed)
   - Task name, progress bar, elapsed time
   - Real-time token usage indicator
   - "View All Tasks" link

3. **Statistics Overview**
   - Today's metrics (tasks completed, failed, pending)
   - Token usage and estimated costs
   - Average task duration
   - Success rate percentage

4. **Quick Actions**
   - Pause/Resume button (prominent)
   - Refresh Queue button
   - View Logs button

### 4.4 Task Queue View

**Layout:**
```
┌─────────────────────────────────────────────────────┐
│  Filters: [All ▾] [Status ▾] [Priority ▾]  [Search]│
├─────────────────────────────────────────────────────┤
│                                                     │
│  PENDING (3)                                        │
│  ┌───────────────────────────────────────────────┐ │
│  │ ⚡ HIGH   Design landing page component        │ │
│  │ Due: 2h  Created: 10 min ago                  │ │
│  │ [View] [Accept Now]                           │ │
│  └───────────────────────────────────────────────┘ │
│                                                     │
│  IN PROGRESS (2)                                    │
│  ┌───────────────────────────────────────────────┐ │
│  │ 🔵 Running  Implement OAuth flow               │ │
│  │ Progress: 60% ████████████░░░░░░░░            │ │
│  │ Elapsed: 8m 23s  Est. Cost: $0.12             │ │
│  │ [View Logs] [Cancel]                          │ │
│  └───────────────────────────────────────────────┘ │
│                                                     │
│  COMPLETED (24)                                     │
│  ┌───────────────────────────────────────────────┐ │
│  │ ✓ Refactor database queries                   │ │
│  │ Completed: 15 min ago  Duration: 12m          │ │
│  │ Cost: $0.08  Output: 3 files                  │ │
│  │ [View Details] [Download Artifacts]           │ │
│  └───────────────────────────────────────────────┘ │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Task Card Elements:**
- Priority indicator (color-coded badge)
- Task title and description
- Status badge with icon
- Progress indicator (for in-progress tasks)
- Metadata: created time, due date, estimated duration
- Action buttons contextual to status
- Expandable details section

### 4.5 Execution Logs View

**Features:**
- Real-time streaming console output
- Syntax highlighting for code blocks
- Log level filtering (Info, Warning, Error)
- Search and filter capabilities
- Export logs functionality
- Auto-scroll toggle

**Layout:**
```
┌─────────────────────────────────────────────────────┐
│  [Task: Implement OAuth] [Level: All ▾] [Search 🔍] │
├─────────────────────────────────────────────────────┤
│ 14:32:01 [INFO]  Task accepted, starting execution  │
│ 14:32:02 [INFO]  Initializing Claude client         │
│ 14:32:05 [INFO]  Sending prompt to Claude API       │
│ 14:32:08 [INFO]  Response received (2,341 tokens)   │
│ 14:32:08 [DEBUG] Processing code artifacts          │
│ 14:32:10 [INFO]  Generated: oauth_handler.py        │
│ 14:32:10 [INFO]  Generated: auth_config.json        │
│ 14:32:11 [WARN]  Token usage: 2,341 / 4,000 limit   │
│ 14:32:15 [INFO]  Task completed successfully        │
│ 14:32:16 [INFO]  Updating ZMemory task status       │
└─────────────────────────────────────────────────────┘
│ [Auto-scroll ✓]  [Clear]  [Export]                  │
└─────────────────────────────────────────────────────┘
```

### 4.6 Settings View

**Sections:**

1. **Connection Settings**
   - ZMemory API URL
   - API Key / OAuth login
   - Connection test button
   - Status indicator

2. **Claude Configuration**
   - Anthropic API key
   - Model selection (Sonnet 4.5, Opus 4, etc.)
   - Max tokens per request
   - Temperature setting
   - Test connection button

3. **Execution Settings**
   - Agent name/identifier
   - Max concurrent tasks (1-5)
   - Polling interval (10s - 5m)
   - Auto-accept tasks toggle
   - Task type filters

4. **Resource Limits**
   - Daily token budget
   - Cost limit per task
   - Maximum task duration
   - Disk space for artifacts

5. **Notifications**
   - Task completion notifications
   - Error notifications
   - Daily summary
   - Sound effects toggle

6. **Advanced**
   - Log retention period
   - Artifact storage location
   - Debug mode
   - Auto-update preferences

---

## 5. User Flows

### 5.1 First-Time Setup Flow

```
1. Launch App
   ↓
2. Welcome Screen
   "Connect to ZMemory"
   ↓
3. Enter ZMemory API credentials
   [Test Connection]
   ↓
4. Enter Anthropic API key
   [Verify]
   ↓
5. Configure basic settings
   - Agent name
   - Concurrent tasks
   ↓
6. Dashboard (Ready to execute)
```

### 5.2 Task Execution Flow

```
Background Process:
┌─────────────────────────────────────────┐
│ Poll ZMemory for pending tasks          │
│ (every 30 seconds)                      │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│ New task found?                         │
└─────────────────────────────────────────┘
        Yes ↓              No ↓ (continue polling)
┌─────────────────────────────────────────┐
│ Check execution capacity                │
│ (max concurrent tasks not reached?)     │
└─────────────────────────────────────────┘
        Yes ↓              No ↓ (queue locally)
┌─────────────────────────────────────────┐
│ Accept task via ZMemory API             │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│ Update status: "in_progress"            │
│ Show in UI with progress indicator      │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│ Build prompt from task instructions     │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│ Send to Claude API                      │
│ Stream response, update UI in real-time │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│ Parse artifacts, save locally           │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│ Complete task in ZMemory                │
│ Upload artifacts, set status            │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│ Show notification                       │
│ Update statistics                       │
└─────────────────────────────────────────┘
```

### 5.3 Error Handling Flow

```
Error occurs during execution
           ↓
Determine error type:
├─ Network error → Retry with backoff
├─ API limit → Queue for later
├─ Invalid task → Mark as failed, notify user
└─ Claude error → Retry once, then fail
           ↓
Update task status in ZMemory
           ↓
Log error details
           ↓
Show notification to user
           ↓
Continue with next task
```

---

## 6. Visual Design System

### 6.1 Color Palette

**Primary Colors:**
- **Zephyr Blue:** `#0066FF` (primary brand color)
- **Success Green:** `#34C759` (completed tasks)
- **Warning Orange:** `#FF9500` (warnings, paused state)
- **Error Red:** `#FF3B30` (failures, critical issues)
- **Neutral Gray:** `#8E8E93` (inactive states)

**Background Colors:**
- **Light Mode BG:** `#FFFFFF` (main), `#F5F5F7` (secondary)
- **Dark Mode BG:** `#1C1C1E` (main), `#2C2C2E` (secondary)

**Text Colors:**
- **Light Mode:** `#000000` (primary), `#6E6E73` (secondary)
- **Dark Mode:** `#FFFFFF` (primary), `#AEAEB2` (secondary)

### 6.2 Typography

- **Headers:** SF Pro Display, Bold, 24-32pt
- **Body:** SF Pro Text, Regular, 13-15pt
- **Code/Logs:** SF Mono, Regular, 11-13pt
- **Small Text:** SF Pro Text, Regular, 11pt

### 6.3 Icons

Use SF Symbols for macOS native feel:
- Dashboard: `gauge.badge.plus`
- Tasks: `checklist`
- Logs: `list.bullet.rectangle`
- Settings: `gearshape.fill`
- Status: `circle.fill` (various colors)
- Execute: `play.circle.fill`
- Pause: `pause.circle.fill`
- Error: `exclamationmark.triangle.fill`

### 6.4 Component Styles

**Buttons:**
- Primary: Filled blue, white text, 8px radius
- Secondary: Gray outline, blue text, 8px radius
- Destructive: Red outline or filled, 8px radius

**Cards:**
- White/dark background with subtle shadow
- 12px border radius
- 16px padding
- 1px border in light mode

**Progress Bars:**
- Height: 6px
- Rounded ends
- Animated gradient for active state
- Blue fill for progress

---

## 7. Technical Architecture

### 7.1 Technology Stack

**Frontend:**
- **SwiftUI** (native macOS UI)
- **Combine** (reactive data flow)
- **AppKit** (menu bar integration)

**Backend:**
- **Swift/Python** hybrid approach
- **URLSession** for API calls
- **Foundation** for file management

**Data Storage:**
- **CoreData** for local task cache
- **FileManager** for artifacts
- **UserDefaults** for settings

### 7.2 System Architecture

```
┌────────────────────────────────────────────┐
│         SwiftUI Application                │
│  ┌──────────────────────────────────────┐  │
│  │       View Layer (UI)                │  │
│  └──────────────────────────────────────┘  │
│                   ↕                        │
│  ┌──────────────────────────────────────┐  │
│  │    ViewModel Layer (State)           │  │
│  │    - TaskQueueViewModel              │  │
│  │    - ExecutorViewModel               │  │
│  │    - LogViewModel                    │  │
│  └──────────────────────────────────────┘  │
│                   ↕                        │
│  ┌──────────────────────────────────────┐  │
│  │       Service Layer                  │  │
│  │  ┌──────────┐  ┌─────────────────┐  │  │
│  │  │ ZMemory  │  │ Claude API      │  │  │
│  │  │ Client   │  │ Client          │  │  │
│  │  └──────────┘  └─────────────────┘  │  │
│  │  ┌──────────┐  ┌─────────────────┐  │  │
│  │  │ Task     │  │ Artifact        │  │  │
│  │  │ Executor │  │ Manager         │  │  │
│  │  └──────────┘  └─────────────────┘  │  │
│  └──────────────────────────────────────┘  │
│                   ↕                        │
│  ┌──────────────────────────────────────┐  │
│  │       Data Layer                     │  │
│  │  - CoreData (task cache)             │  │
│  │  - FileManager (artifacts)           │  │
│  │  - UserDefaults (settings)           │  │
│  └──────────────────────────────────────┘  │
└────────────────────────────────────────────┘
           ↕                    ↕
   ┌────────────┐        ┌───────────────┐
   │  ZMemory   │        │ Claude API    │
   │  API       │        │ (Anthropic)   │
   └────────────┘        └───────────────┘
```

### 7.3 Key Components

**1. TaskPollingService**
- Background timer-based polling
- Respects system sleep/wake
- Adjustable interval (30s default)
- Network-aware (pauses on disconnect)

**2. TaskExecutor**
- Queue management (FIFO with priority)
- Concurrent execution (configurable limit)
- Timeout handling
- Retry logic with exponential backoff

**3. ClaudeClient**
- Streaming response handling
- Token counting and budget tracking
- Error handling and retry
- Request/response logging

**4. ArtifactManager**
- File system operations
- Artifact versioning
- Compression for large files
- Upload to ZMemory

**5. NotificationService**
- Native macOS notifications
- Customizable triggers
- Sound effects
- Notification center integration

---

## 8. Key Features

### 8.1 Core Features (MVP)

✅ Connect to ZMemory API
✅ Poll for pending AI tasks
✅ Execute tasks with Claude API
✅ Report results back to ZMemory
✅ Display task queue and status
✅ View execution logs
✅ Basic settings configuration
✅ Menu bar status indicator
✅ Error handling and retry

### 8.2 Enhanced Features (V1.1+)

🔲 Multi-agent support (multiple Claude instances)
🔲 Task scheduling (cron-like)
🔲 Custom task templates
🔲 Artifact preview and editing
🔲 Cost analytics and budgeting
🔲 Performance metrics dashboard
🔲 Task priority override
🔲 Batch task execution
🔲 Integration with local dev tools
🔲 Export reports (CSV, PDF)

### 8.3 Advanced Features (V2.0+)

🔲 Plugin system for custom task types
🔲 Collaborative execution (multi-machine)
🔲 AI-powered task optimization
🔲 Code review and validation
🔲 Automated testing integration
🔲 Git integration for artifacts
🔲 Team dashboard (web-based)
🔲 Slack/Discord notifications

---

## 9. Performance Requirements

- **Polling Latency:** < 5 seconds from task creation to detection
- **Execution Start:** < 2 seconds from detection to Claude API call
- **UI Responsiveness:** All interactions < 100ms
- **Memory Usage:** < 200MB idle, < 500MB during execution
- **CPU Usage:** < 5% idle, < 20% during execution
- **Network Efficiency:** Batch API calls when possible

---

## 10. Security Considerations

1. **API Key Storage:** Use macOS Keychain for secure storage
2. **Artifact Isolation:** Sandboxed execution environment
3. **Network Security:** TLS 1.3 for all API calls
4. **Code Validation:** Static analysis of generated code
5. **Access Control:** Local authentication for sensitive operations
6. **Audit Logging:** Complete audit trail of all operations

---

## 11. Development Phases

### Phase 1: Foundation (2-3 weeks)
- Project setup and architecture
- ZMemory API integration
- Claude API integration
- Basic UI framework

### Phase 2: Core Features (3-4 weeks)
- Task polling and queue management
- Task execution engine
- Logs and monitoring
- Settings interface

### Phase 3: Polish & Testing (2-3 weeks)
- UI refinement and animations
- Error handling improvements
- Performance optimization
- Beta testing

### Phase 4: Launch (1 week)
- Documentation
- App Store submission (optional)
- Release and monitoring

---

## 12. Success Metrics

- **Reliability:** >99% task completion rate
- **Performance:** <30s average task latency
- **User Satisfaction:** NPS >50
- **Adoption:** 100 active users in first month
- **Cost Efficiency:** <$0.50 avg cost per task

---

## Appendix: Mockups

### Dashboard View (Light Mode)
```
┌────────────────────────────────────────────────────────┐
│  ●  ●  ●            ZephyrOS Executor                  │
├────────────────────────────────────────────────────────┤
│ 􀎟 Dashboard  │  ╔════════════════════════════════╗   │
│ 􀐱 Tasks       │  ║  STATUS: ● Running             ║   │
│ 􀉆 Logs        │  ║  Connected to ZMemory          ║   │
│ ⚙️ Settings    │  ║  2 tasks in progress           ║   │
│                │  ║  Last sync: 5 seconds ago      ║   │
│                │  ╚════════════════════════════════╝   │
│                │                                        │
│                │  ACTIVE TASKS                          │
│                │  ┌──────────────────────────────────┐ │
│                │  │ 🔵 Refactor authentication       │ │
│                │  │    Progress: 65%                 │ │
│                │  │    ██████████████░░░░░░░         │ │
│                │  │    Elapsed: 8m 12s               │ │
│                │  └──────────────────────────────────┘ │
│                │                                        │
│                │  TODAY'S STATS                         │
│                │  ┌──────────┬──────────┬──────────┐   │
│                │  │ Tasks    │ Success  │ Cost     │   │
│                │  │ 12       │ 91%      │ $2.34    │   │
│                │  └──────────┴──────────┴──────────┘   │
│                │                                        │
│                │  [⏸ Pause]  [🔄 Refresh]  [📊 Logs]   │
└────────────────────────────────────────────────────────┘
```

This design provides a solid foundation for building your ZephyrOS Local Executor. Would you like me to dive deeper into any specific section, or shall we start implementing a particular component?