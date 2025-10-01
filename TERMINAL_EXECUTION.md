# Terminal Execution Mode

ZephyrOS Executor now supports two execution modes:

1. **API Mode** (default): Tasks are executed via direct Claude API calls
2. **Terminal Mode** (new): Tasks are executed by spawning Terminal.app with Claude Code CLI

Terminal mode provides full tool access, allowing Claude Code to read/write files, execute bash commands, and perform complex multi-step workflows visible in a real terminal window.

## Overview

### Architecture

```
┌─────────────┐     Poll      ┌──────────────────────┐
│   ZMemory   │ ←────────────  │  Terminal Executor   │
│   Backend   │                │                      │
└─────────────┘                └──────────────────────┘
       ↑                              │
       │ Report Results               │ Spawn Terminal
       │                              ↓
       │                       ┌──────────────────────┐
       └───────────────────────│  Terminal.app        │
                               │  Claude Code CLI     │
                               └──────────────────────┘
```

### Key Features

✅ **Visible Terminal Windows**: See Claude Code execution in real-time on macOS
✅ **Full Tool Access**: Claude can read/write files, run bash commands, use git
✅ **Isolated Workspaces**: Each task runs in its own directory
✅ **Artifact Collection**: Automatically collects generated files
✅ **Progress Monitoring**: Real-time output streaming and progress tracking
✅ **Flexible Configuration**: Per-task or global execution mode

## Installation

### Prerequisites

1. **Claude Code CLI** must be installed:
   ```bash
   # Install Claude Code
   npm install -g @anthropics/claude-code

   # Or follow official installation instructions
   ```

2. **macOS Terminal.app or iTerm2**

3. **Existing ZephyrOS Executor setup** (Python CLI)

### Verify Installation

```bash
# Check Claude Code is installed
which claude
# Should output: /usr/local/bin/claude (or similar)

claude --version
# Should show version number
```

## Configuration

### Environment Variables

Update your `.env` file:

```bash
# Set execution mode to terminal
EXECUTION_MODE=terminal

# Claude Code CLI path (optional if in standard location)
CLAUDE_CODE_PATH=/usr/local/bin/claude

# Show terminal windows (true/false)
SHOW_TERMINAL_WINDOW=true

# Terminal app to use (Terminal or iTerm)
TERMINAL_APP=Terminal

# Workspace directory for task execution
WORKSPACE_BASE_DIR=/tmp/zephyros-tasks

# Auto-cleanup old workspaces (true/false)
AUTO_CLEANUP_WORKSPACES=true

# Maximum workspace age before cleanup (hours)
MAX_WORKSPACE_AGE_HOURS=24
```

### Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `EXECUTION_MODE` | `api` | Execution mode: `api` or `terminal` |
| `CLAUDE_CODE_PATH` | `/usr/local/bin/claude` | Path to Claude CLI |
| `SHOW_TERMINAL_WINDOW` | `true` | Show terminal window (macOS) |
| `TERMINAL_APP` | `Terminal` | Terminal app: `Terminal` or `iTerm` |
| `WORKSPACE_BASE_DIR` | `/tmp/zephyros-tasks` | Base directory for workspaces |
| `AUTO_CLEANUP_WORKSPACES` | `true` | Auto-remove completed workspaces |
| `MAX_WORKSPACE_AGE_HOURS` | `24` | Max age before workspace cleanup |

## Usage

### Basic Usage

1. **Update `.env` to enable terminal mode:**
   ```bash
   EXECUTION_MODE=terminal
   ```

2. **Start the executor:**
   ```bash
   python main.py
   ```

3. **Create tasks in ZMemory** (they will automatically use terminal mode)

4. **Watch execution** in Terminal.app windows that open automatically

### Per-Task Execution Mode

You can override the execution mode per task:

```python
# In ZMemory, when creating a task
task = {
    'id': 'task-123',
    'description': 'Refactor authentication code to use async/await',
    'execution_mode': 'terminal',  # Override: use terminal for this task
    'files': {
        'src/auth.py': '...',  # Include relevant files
    }
}
```

### Task Structure for Terminal Mode

Tasks can include files, context, and specific instructions:

```python
task = {
    'id': 'task-456',
    'description': '''
        Review the codebase in ./input/ and:
        1. Fix any type errors
        2. Add unit tests
        3. Update documentation

        Place all output files in ./output/
    ''',
    'execution_mode': 'terminal',
    'files': {
        'main.py': '...',      # Files are placed in workspace/input/
        'config.py': '...',
    },
    'context': {
        'framework': 'FastAPI',
        'python_version': '3.11',
        'requirements': ['Must maintain backward compatibility']
    }
}
```

## Workspace Structure

Each task gets an isolated workspace:

```
/tmp/zephyros-tasks/
└── task-123_20251001_140523/
    ├── input/              # Input files from task
    │   ├── main.py
    │   └── config.py
    ├── output/             # Generated files (collected as artifacts)
    │   ├── fixed_main.py
    │   └── tests.py
    ├── logs/               # Execution logs
    ├── task_context.json   # Task context/metadata
    ├── task-123_output.log # Claude Code output
    └── .claude/            # Claude Code configuration
        └── settings.json
```

### Workspace Lifecycle

1. **Creation**: Workspace created when task starts
2. **Preparation**: Input files written, context saved
3. **Execution**: Terminal spawned, Claude Code runs
4. **Collection**: Output files collected as artifacts
5. **Cleanup**: Workspace removed after completion (if `AUTO_CLEANUP_WORKSPACES=true`)

## How It Works

### Execution Flow

```
1. Task received from ZMemory
   ↓
2. Create isolated workspace
   ↓
3. Write input files to workspace/input/
   ↓
4. Format task prompt for Claude Code
   ↓
5. Spawn Terminal.app with Claude Code
   ↓
6. Monitor execution (stream output)
   ↓
7. Detect completion
   ↓
8. Collect artifacts from workspace/output/
   ↓
9. Report results to ZMemory
   ↓
10. Cleanup workspace (optional)
```

### Terminal Session Management

The `TerminalSessionManager` handles:

- **Spawning**: Opens Terminal.app using AppleScript
- **Monitoring**: Tracks process status and output
- **Control**: Can terminate sessions if needed
- **Cleanup**: Closes terminal and removes session data

### Output Monitoring

Real-time output capture:

```python
# Output is continuously streamed to log files
# Progress updates sent to ZMemory
# Artifacts collected from workspace/output/
```

## Examples

### Example 1: Code Refactoring

```python
task = {
    'id': 'refactor-001',
    'description': 'Refactor src/auth.py to use async/await patterns',
    'execution_mode': 'terminal',
    'files': {
        'src/auth.py': open('src/auth.py').read(),
    }
}
```

**Terminal Output:**
```
=== ZephyrOS Task Execution ===
Task ID: refactor-001
Started: Wed Oct 1 14:05:23 PDT 2025
================================

[Claude Code runs, showing real-time progress]
Reading src/auth.py...
Analyzing authentication patterns...
Converting to async/await...
Writing refactored code to ./output/auth.py...

================================
Finished: Wed Oct 1 14:06:45 PDT 2025
Exit code: 0
================================
```

### Example 2: Multi-File Project

```python
task = {
    'id': 'project-002',
    'description': '''
        Create a FastAPI REST API with:
        - User authentication endpoints
        - CRUD operations for tasks
        - Input validation with Pydantic
        - Unit tests with pytest

        Save all files to ./output/
    ''',
    'execution_mode': 'terminal',
    'context': {
        'framework': 'FastAPI',
        'database': 'PostgreSQL',
        'orm': 'SQLAlchemy'
    }
}
```

**Artifacts Collected:**
```
output/
├── main.py
├── models.py
├── routers/
│   ├── auth.py
│   └── tasks.py
├── tests/
│   ├── test_auth.py
│   └── test_tasks.py
└── requirements.txt
```

### Example 3: Testing Existing Code

```python
task = {
    'id': 'test-003',
    'description': 'Run tests and fix any failures',
    'execution_mode': 'terminal',
    'files': {
        'src/calculator.py': '...',
        'tests/test_calculator.py': '...',
        'pytest.ini': '...',
    }
}
```

Claude Code can:
- Run `pytest`
- Analyze failures
- Fix bugs
- Re-run tests
- Report results

## Benefits Over API Mode

| Feature | API Mode | Terminal Mode |
|---------|----------|---------------|
| **Tool Access** | ❌ None | ✅ Full (files, bash, git) |
| **Visibility** | ❌ No UI | ✅ Live terminal output |
| **File Operations** | ❌ Limited | ✅ Read/write anywhere |
| **Code Execution** | ❌ No | ✅ Run scripts, tests |
| **Multi-step Tasks** | ⚠️ Limited | ✅ Complex workflows |
| **Debugging** | ❌ Difficult | ✅ Can inspect state |
| **Speed** | ✅ Faster | ⚠️ Overhead from terminal |
| **Resource Usage** | ✅ Lower | ⚠️ Higher (terminal process) |

## Troubleshooting

### Terminal Not Opening

**Problem**: Terminal window doesn't appear

**Solutions**:
1. Check Terminal.app accessibility permissions:
   ```
   System Settings → Privacy & Security → Automation
   → Allow Python to control Terminal.app
   ```

2. Verify AppleScript works:
   ```bash
   osascript -e 'tell application "Terminal" to activate'
   ```

3. Check logs:
   ```bash
   tail -f /tmp/zephyros-tasks/*/task-*_output.log
   ```

### Claude Code Not Found

**Problem**: `claude` command not found

**Solutions**:
1. Install Claude Code:
   ```bash
   npm install -g @anthropics/claude-code
   ```

2. Update `CLAUDE_CODE_PATH` in `.env`:
   ```bash
   CLAUDE_CODE_PATH=/path/to/claude
   ```

3. Check installation:
   ```bash
   which claude
   ```

### Tasks Timing Out

**Problem**: Tasks exceed timeout limit

**Solutions**:
1. Increase timeout in `.env`:
   ```bash
   TASK_TIMEOUT_SECONDS=1200  # 20 minutes
   ```

2. Check task complexity
3. Monitor resource usage

### Workspace Permissions

**Problem**: Cannot write to workspace directory

**Solutions**:
1. Change workspace location:
   ```bash
   WORKSPACE_BASE_DIR=~/zephyros-workspaces
   ```

2. Check permissions:
   ```bash
   mkdir -p /tmp/zephyros-tasks
   chmod 755 /tmp/zephyros-tasks
   ```

## Advanced Configuration

### Custom Terminal Script

Modify the script generation in `terminal_manager.py`:

```python
script_content = f"""#!/bin/bash
cd "{session.workspace}"

# Your custom setup here
export MY_VAR="value"

# Run Claude Code
{self.claude_path} '{escaped_prompt}' 2>&1 | tee "{session.output_file}"

exit $?
"""
```

### iTerm2 Integration

Use iTerm2 instead of Terminal.app:

```bash
TERMINAL_APP=iTerm
```

### Headless Mode

Run without visible terminals:

```bash
SHOW_TERMINAL_WINDOW=false
```

Tasks will still execute using Claude Code, but in background processes.

## Security Considerations

1. **Workspace Isolation**: Each task runs in its own directory
2. **File Access**: Claude Code can only access workspace files (by default)
3. **Tool Approval**: Configure Claude Code to require approval for sensitive operations
4. **Cleanup**: Enable `AUTO_CLEANUP_WORKSPACES` to remove task data
5. **Monitoring**: All commands and output are logged

### Restrict Claude Code Access

Edit workspace `.claude/settings.json`:

```json
{
  "auto_approve": false,
  "restricted_tools": ["bash"],
  "allowed_paths": ["./input", "./output"]
}
```

## Performance Tips

1. **Limit Concurrent Tasks**: Terminal mode uses more resources
   ```bash
   MAX_CONCURRENT_TASKS=1  # For terminal mode
   ```

2. **Enable Cleanup**: Keep disk usage low
   ```bash
   AUTO_CLEANUP_WORKSPACES=true
   MAX_WORKSPACE_AGE_HOURS=12
   ```

3. **Monitor Resources**:
   ```bash
   # Watch process count
   ps aux | grep claude | wc -l

   # Check disk usage
   du -sh /tmp/zephyros-tasks
   ```

## Future Enhancements

- [ ] WebSocket streaming for real-time UI updates
- [ ] Docker container isolation per task
- [ ] Recording/replay of terminal sessions
- [ ] Integration with macOS Screen Recording API
- [ ] Custom tool restrictions per task type
- [ ] Parallel terminal execution with better resource management

## Support

For issues or questions:

1. Check logs: `tail -f /tmp/zephyros-tasks/*/task-*_output.log`
2. Enable debug logging in `cli.py`
3. Review terminal session status in output
4. Open GitHub issue with logs and configuration

## See Also

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture details
- [README.md](README.md) - Main documentation
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Setup instructions
