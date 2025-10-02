# Agent Workspace Architecture Design

## Overview
Design for isolated, automated agent execution environments with workspace sandboxing, Claude Code automation, and result collection.

---

## 1. Architecture Components

### 1.1 Agent Workspace Structure
```
~/ZephyrOS/Workspaces/
├── agent-{agentId}/
│   ├── tasks/
│   │   ├── task-{taskId}-{timestamp}/
│   │   │   ├── workspace/           # Actual project/repo
│   │   │   ├── .zephyr/             # Metadata & config
│   │   │   │   ├── config.json      # Workspace config
│   │   │   │   ├── task.json        # Original task data
│   │   │   │   ├── prompts/         # Claude Code prompts
│   │   │   │   ├── outputs/         # Result files
│   │   │   │   └── logs/            # Execution logs
│   │   │   └── result.json          # Final structured output
```

### 1.2 Workspace Isolation Levels

**Option A: Soft Isolation (Recommended for MVP)**
- Create dedicated workspace folder per task
- Terminal starts in workspace root
- Rely on well-designed prompts to keep agents in scope
- Easy to debug and inspect
- **Pros:** Simple, debuggable, flexible
- **Cons:** Agent could escape if prompts are poor

**Option B: Hard Isolation (Future Enhancement)**
- Use macOS sandbox-exec to restrict file access
- Container-like isolation per workspace
- **Pros:** True security isolation
- **Cons:** Complex, harder to debug

**Recommendation:** Start with Soft Isolation, add Hard Isolation later if needed.

---

## 2. Component Design

### 2.1 AgentWorkspace Model

```swift
struct AgentWorkspace: Codable, Identifiable {
    let id: String                    // UUID
    let agentId: String
    let taskId: String
    let aiTaskId: String
    let rootPath: URL                 // ~/ZephyrOS/Workspaces/agent-X/task-Y
    let workspacePath: URL            // rootPath/workspace
    let metadataPath: URL             // rootPath/.zephyr
    let status: WorkspaceStatus
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?

    // Configuration
    var repoURL: String?              // Git repo to clone
    var projectType: ProjectType?     // swift, python, node, etc.
    var allowedCommands: [String]?    // Whitelist of shell commands

    enum WorkspaceStatus: String, Codable {
        case creating
        case ready
        case running
        case completed
        case failed
        case archived
    }

    enum ProjectType: String, Codable {
        case swift
        case python
        case nodejs
        case go
        case generic
    }
}
```

### 2.2 WorkspaceManager

**Responsibilities:**
- Create/destroy workspace directories
- Setup project structure
- Clone repositories
- Manage workspace lifecycle
- Enforce workspace boundaries

```swift
class WorkspaceManager: ObservableObject {
    static let shared = WorkspaceManager()

    @Published var activeWorkspaces: [AgentWorkspace] = []

    private let baseWorkspacePath: URL  // ~/ZephyrOS/Workspaces

    // Lifecycle
    func createWorkspace(for task: AITask, agent: AIAgent) async throws -> AgentWorkspace
    func setupRepository(workspace: AgentWorkspace, repoURL: String) async throws
    func cleanupWorkspace(id: String) async throws
    func archiveWorkspace(id: String) async throws -> URL

    // Access control
    func validatePath(_ path: String, in workspace: AgentWorkspace) -> Bool
    func getWorkspaceTerminal(for workspace: AgentWorkspace) -> PTYTerminalController
}
```

### 2.3 Claude Code Automation

**Approaches:**

**A. AppleScript Automation (Recommended)**
```applescript
tell application "Claude"
    activate
    set workspaceFolder to "/path/to/workspace"
    open workspaceFolder

    -- Send prompt via keyboard automation
    tell application "System Events"
        keystroke "Your prompt here"
        key code 36  -- Enter
    end tell
end tell
```

**B. URL Scheme (If supported)**
```
claude://workspace?path=/path/to/workspace&prompt=encoded-prompt
```

**C. CLI Integration (Best if available)**
```bash
claude code --workspace /path/to/workspace --prompt "@prompts/task.md" --output outputs/result.md
```

**Implementation:**
```swift
class ClaudeCodeAutomation {
    func openWorkspace(path: URL) async throws
    func executePrompt(prompt: String, outputFile: String) async throws
    func waitForCompletion(timeout: TimeInterval) async throws
    func extractResult(from outputFile: URL) async throws -> String
}
```

### 2.4 File Monitor & Result Parser

```swift
class WorkspaceFileMonitor {
    private var fileWatcher: DispatchSourceFileSystemObject?

    func watchForFile(at path: URL, timeout: TimeInterval) async throws -> URL
    func stopWatching()
}

class ResultParser {
    func parseResultFile(_ url: URL) async throws -> TaskResult

    struct TaskResult: Codable {
        let success: Bool
        let output: String
        let files: [String]           // Generated/modified files
        let errors: [String]?
        let metadata: [String: Any]?
    }
}
```

---

## 3. Execution Flow

### 3.1 Complete Task Execution Pipeline

```swift
class AgentTaskExecutor {
    let workspaceManager: WorkspaceManager
    let claudeAutomation: ClaudeCodeAutomation
    let fileMonitor: WorkspaceFileMonitor
    let resultParser: ResultParser
    let zmemoryClient: ZMemoryClient

    func executeTask(_ aiTask: AITask) async throws {
        // 1. Create isolated workspace
        let workspace = try await workspaceManager.createWorkspace(for: aiTask)

        // 2. Setup project/repo
        if let repoURL = aiTask.metadata?.repoURL {
            try await workspaceManager.setupRepository(workspace: workspace, repoURL: repoURL)
        }

        // 3. Prepare prompt file
        let promptFile = workspace.metadataPath
            .appendingPathComponent("prompts")
            .appendingPathComponent("main.md")
        try aiTask.objective.write(to: promptFile, atomically: true, encoding: .utf8)

        // 4. Open Claude Code with workspace
        try await claudeAutomation.openWorkspace(path: workspace.workspacePath)

        // 5. Start file monitoring
        let outputFile = workspace.metadataPath
            .appendingPathComponent("outputs")
            .appendingPathComponent("result.md")

        Task {
            do {
                let resultURL = try await fileMonitor.watchForFile(
                    at: outputFile,
                    timeout: aiTask.estimatedDurationMin ?? 30 * 60
                )

                // 6. Parse result
                let result = try await resultParser.parseResultFile(resultURL)

                // 7. Send back to ZMemory
                try await zmemoryClient.updateAITaskResult(
                    id: aiTask.id,
                    result: result
                )

                // 8. Cleanup
                try await workspaceManager.archiveWorkspace(id: workspace.id)

            } catch {
                // Handle timeout or errors
                try? await zmemoryClient.updateAITaskStatus(
                    id: aiTask.id,
                    status: .failed,
                    error: error.localizedDescription
                )
            }
        }
    }
}
```

---

## 4. Reliability Improvements

### 4.1 Error Handling & Recovery

```swift
enum WorkspaceError: Error {
    case creationFailed(reason: String)
    case repositoryCloneFailed
    case claudeCodeNotAvailable
    case resultTimeout
    case parseError
    case invalidOutput
}

// Retry logic
func executeWithRetry<T>(
    maxAttempts: Int = 3,
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            if attempt < maxAttempts {
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
            }
        }
    }

    throw lastError!
}
```

### 4.2 Timeout & Progress Monitoring

```swift
class TaskProgressMonitor {
    func monitorTask(_ task: AITask, workspace: AgentWorkspace) async {
        // Watch for file changes
        // Monitor terminal output
        // Send progress updates to ZMemory
        // Detect stuck tasks
    }
}
```

### 4.3 Resource Management

```swift
class WorkspaceResourceManager {
    private let maxConcurrentWorkspaces = 5
    private let maxWorkspaceSize: Int64 = 5 * 1024 * 1024 * 1024  // 5GB

    func checkResources() -> Bool
    func cleanupOldWorkspaces() async
    func enforceQuotas() async
}
```

### 4.4 Structured Output Format

**Require agents to output in this format:**

```json
{
  "success": true,
  "task_id": "task-123",
  "agent_id": "agent-456",
  "timestamp": "2025-10-02T00:00:00Z",
  "output": {
    "summary": "Completed refactoring UserService",
    "files_modified": [
      "src/services/UserService.swift",
      "tests/UserServiceTests.swift"
    ],
    "tests_passed": true,
    "build_succeeded": true
  },
  "logs": [
    "Analyzed codebase structure",
    "Refactored authentication logic",
    "Updated unit tests",
    "All tests passing"
  ],
  "errors": [],
  "metadata": {
    "lines_changed": 145,
    "test_coverage": 0.87
  }
}
```

---

## 5. Security Considerations

### 5.1 Workspace Sandboxing (Future)

```bash
# Use sandbox-exec for true isolation
sandbox-exec -f workspace.sb /bin/zsh

# workspace.sb profile:
(version 1)
(deny default)
(allow file-read* file-write* (subpath "/path/to/workspace"))
(allow process-exec (literal "/bin/zsh"))
(allow network-outbound)  # If needed for git, npm, etc.
```

### 5.2 Command Whitelisting

```swift
class CommandValidator {
    static let allowedCommands = [
        "git", "npm", "python", "swift", "xcodebuild",
        "ls", "cd", "cat", "echo", "mkdir", "touch"
    ]

    func validateCommand(_ command: String) -> Bool {
        let parts = command.split(separator: " ")
        guard let executable = parts.first else { return false }
        return Self.allowedCommands.contains(String(executable))
    }
}
```

### 5.3 Path Validation

```swift
extension WorkspaceManager {
    func isPathInWorkspace(_ path: String, workspace: AgentWorkspace) -> Bool {
        let resolvedPath = URL(fileURLWithPath: path).standardized
        return resolvedPath.path.hasPrefix(workspace.workspacePath.path)
    }
}
```

---

## 6. Alternative: Claude Code CLI Integration

**If Claude Code supports CLI (check docs):**

```bash
# Ideal workflow
claude code \
  --workspace /path/to/workspace \
  --prompt-file prompts/task.md \
  --output-file outputs/result.md \
  --wait

# Then read outputs/result.md
```

**Benefits:**
- No AppleScript hacks
- Reliable automation
- Proper error codes
- Scriptable

---

## 7. Implementation Priority

### Phase 1: MVP (Week 1)
- ✅ AgentWorkspace model
- ✅ WorkspaceManager with directory creation
- ✅ Terminal integration with workspace root
- ✅ Manual Claude Code workflow (document steps)
- ✅ File monitoring for result.json
- ✅ ZMemory integration

### Phase 2: Automation (Week 2)
- ✅ Claude Code AppleScript automation
- ✅ Automatic prompt injection
- ✅ Result parsing
- ✅ Error handling & retries

### Phase 3: Hardening (Week 3)
- ✅ Command whitelisting
- ✅ Path validation
- ✅ Resource quotas
- ✅ Workspace archiving

### Phase 4: Advanced (Future)
- ✅ sandbox-exec integration
- ✅ Multi-agent orchestration
- ✅ Workspace templates
- ✅ Performance monitoring

---

## 8. Testing Strategy

```swift
class WorkspaceTests: XCTestCase {
    func testWorkspaceCreation()
    func testRepositoryCloning()
    func testPathIsolation()
    func testResultParsing()
    func testCleanup()
    func testConcurrentWorkspaces()
    func testResourceLimits()
}
```

---

## 9. Monitoring & Observability

```swift
struct WorkspaceMetrics {
    var totalWorkspacesCreated: Int
    var activeWorkspaces: Int
    var successRate: Double
    var averageExecutionTime: TimeInterval
    var diskUsage: Int64
}

class WorkspaceAnalytics {
    func recordTaskStart(workspaceId: String)
    func recordTaskCompletion(workspaceId: String, success: Bool, duration: TimeInterval)
    func getMetrics() -> WorkspaceMetrics
}
```

---

## Summary

This design provides:
✅ **Isolation** - Each task gets its own workspace
✅ **Automation** - Claude Code integration
✅ **Reliability** - Retries, timeouts, error handling
✅ **Observability** - Logging, monitoring, metrics
✅ **Scalability** - Resource management, cleanup
✅ **Security** - Path validation, sandboxing (future)

**Next Steps:**
1. Implement AgentWorkspace model
2. Create WorkspaceManager
3. Test workspace creation & terminal integration
4. Research Claude Code automation options
5. Build file monitoring system
6. Integrate with ZMemory
