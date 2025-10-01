"""
Terminal Session Manager
Manages Claude Code terminal sessions for task execution with macOS Terminal.app visibility.
"""

import subprocess
import os
import logging
import time
from typing import Dict, Any, Optional, List
from pathlib import Path
from dataclasses import dataclass
import threading
import select

logger = logging.getLogger(__name__)


@dataclass
class TerminalSession:
    """Represents an active terminal session."""
    id: str
    task_id: str
    workspace: Path
    process: Optional[subprocess.Popen] = None
    output_file: Optional[Path] = None
    error_file: Optional[Path] = None
    start_time: float = 0
    pid: Optional[int] = None
    window_id: Optional[str] = None


class TerminalSessionManager:
    """Manages Claude Code terminal sessions with macOS Terminal.app integration."""

    def __init__(self,
                 claude_path: str = "/usr/local/bin/claude",
                 show_window: bool = True,
                 terminal_app: str = "Terminal"):
        """
        Initialize terminal session manager.

        Args:
            claude_path: Path to Claude Code CLI executable
            show_window: Whether to show terminal window (macOS)
            terminal_app: Terminal application to use (Terminal or iTerm)
        """
        self.claude_path = claude_path
        self.show_window = show_window
        self.terminal_app = terminal_app
        self.active_sessions: Dict[str, TerminalSession] = {}
        self._lock = threading.Lock()

        # Verify Claude Code is installed
        if not self._verify_claude_installed():
            logger.warning(f"Claude Code not found at {claude_path}")

    def _verify_claude_installed(self) -> bool:
        """Check if Claude Code CLI is installed."""
        try:
            result = subprocess.run(
                [self.claude_path, "--version"],
                capture_output=True,
                timeout=5
            )
            return result.returncode == 0
        except Exception as e:
            logger.error(f"Failed to verify Claude installation: {e}")
            return False

    def spawn_terminal(self,
                      task_id: str,
                      workspace: Path,
                      task_prompt: str,
                      timeout: int = 600) -> TerminalSession:
        """
        Spawn a new terminal running Claude Code.

        Args:
            task_id: Unique task identifier
            workspace: Working directory for the task
            task_prompt: Task description to send to Claude
            timeout: Maximum execution time in seconds

        Returns:
            TerminalSession object
        """
        session_id = f"session-{task_id}-{int(time.time())}"

        # Prepare output files
        output_file = workspace / f"{task_id}_output.log"
        error_file = workspace / f"{task_id}_error.log"

        session = TerminalSession(
            id=session_id,
            task_id=task_id,
            workspace=workspace,
            output_file=output_file,
            error_file=error_file,
            start_time=time.time()
        )

        try:
            if self.show_window and self.terminal_app == "Terminal":
                # Use macOS Terminal.app with visible window
                session = self._spawn_macos_terminal(session, task_prompt, timeout)
            elif self.show_window and self.terminal_app == "iTerm":
                # Use iTerm2 with visible window
                session = self._spawn_iterm(session, task_prompt, timeout)
            else:
                # Use headless subprocess
                session = self._spawn_headless(session, task_prompt, timeout)

            with self._lock:
                self.active_sessions[session_id] = session

            logger.info(f"Spawned terminal session {session_id} for task {task_id}")
            return session

        except Exception as e:
            logger.error(f"Failed to spawn terminal for task {task_id}: {e}")
            raise

    def _spawn_macos_terminal(self,
                             session: TerminalSession,
                             task_prompt: str,
                             timeout: int) -> TerminalSession:
        """Spawn Terminal.app with visible window on macOS."""

        # Create a shell script to run in the terminal
        script_path = session.workspace / f"{session.task_id}_run.sh"

        # Escape single quotes in task_prompt
        escaped_prompt = task_prompt.replace("'", "'\"'\"'")

        script_content = f"""#!/bin/bash
cd "{session.workspace}"

echo "=== ZephyrOS Task Execution ==="
echo "Task ID: {session.task_id}"
echo "Started: $(date)"
echo "================================"
echo ""

# Run Claude Code with the task
{self.claude_path} '{escaped_prompt}' 2>&1 | tee "{session.output_file}"

exit_code=$?
echo ""
echo "================================"
echo "Finished: $(date)"
echo "Exit code: $exit_code"
echo "================================"

# Keep window open for a moment to see results
sleep 2

exit $exit_code
"""

        with open(script_path, 'w') as f:
            f.write(script_content)

        # Make script executable
        os.chmod(script_path, 0o755)

        # Use AppleScript to open Terminal.app
        applescript = f'''
tell application "Terminal"
    activate
    set newTab to do script "{script_path}"
    set custom title of newTab to "ZephyrOS Task: {session.task_id}"
end tell
'''

        try:
            # Execute AppleScript
            result = subprocess.run(
                ['osascript', '-e', applescript],
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode != 0:
                raise RuntimeError(f"AppleScript failed: {result.stderr}")

            # Find the spawned process
            time.sleep(1)  # Give terminal time to start
            session.pid = self._find_process_by_script(script_path)

            logger.info(f"Spawned macOS Terminal for task {session.task_id} (PID: {session.pid})")

        except Exception as e:
            logger.error(f"Failed to spawn macOS Terminal: {e}")
            raise

        return session

    def _spawn_iterm(self,
                    session: TerminalSession,
                    task_prompt: str,
                    timeout: int) -> TerminalSession:
        """Spawn iTerm2 with visible window on macOS."""

        # Create script similar to Terminal.app
        script_path = session.workspace / f"{session.task_id}_run.sh"
        escaped_prompt = task_prompt.replace("'", "'\"'\"'")

        script_content = f"""#!/bin/bash
cd "{session.workspace}"
echo "=== ZephyrOS Task Execution ==="
{self.claude_path} '{escaped_prompt}' 2>&1 | tee "{session.output_file}"
exit_code=$?
echo "Exit code: $exit_code"
sleep 2
exit $exit_code
"""

        with open(script_path, 'w') as f:
            f.write(script_content)
        os.chmod(script_path, 0o755)

        # iTerm AppleScript
        applescript = f'''
tell application "iTerm"
    create window with default profile
    tell current session of current window
        write text "{script_path}"
        set name to "ZephyrOS: {session.task_id}"
    end tell
end tell
'''

        subprocess.run(['osascript', '-e', applescript], capture_output=True)
        time.sleep(1)
        session.pid = self._find_process_by_script(script_path)

        return session

    def _spawn_headless(self,
                       session: TerminalSession,
                       task_prompt: str,
                       timeout: int) -> TerminalSession:
        """Spawn Claude Code in headless subprocess (no visible terminal)."""

        try:
            # Start Claude Code process
            process = subprocess.Popen(
                [self.claude_path, task_prompt],
                cwd=str(session.workspace),
                stdout=open(session.output_file, 'w'),
                stderr=open(session.error_file, 'w'),
                stdin=subprocess.PIPE,
                text=True
            )

            session.process = process
            session.pid = process.pid

            logger.info(f"Spawned headless Claude process (PID: {session.pid})")

        except Exception as e:
            logger.error(f"Failed to spawn headless process: {e}")
            raise

        return session

    def _find_process_by_script(self, script_path: Path) -> Optional[int]:
        """Find process ID by script path."""
        try:
            result = subprocess.run(
                ['pgrep', '-f', str(script_path)],
                capture_output=True,
                text=True
            )
            if result.stdout.strip():
                return int(result.stdout.strip().split()[0])
        except Exception as e:
            logger.warning(f"Could not find process: {e}")
        return None

    def is_running(self, session_id: str) -> bool:
        """Check if a session is still running."""
        with self._lock:
            session = self.active_sessions.get(session_id)

        if not session:
            return False

        if session.process:
            return session.process.poll() is None

        # Check by PID
        if session.pid:
            try:
                os.kill(session.pid, 0)  # Send signal 0 to check if alive
                return True
            except OSError:
                return False

        return False

    def get_output(self, session_id: str) -> str:
        """Read current output from session."""
        with self._lock:
            session = self.active_sessions.get(session_id)

        if not session or not session.output_file:
            return ""

        try:
            if session.output_file.exists():
                return session.output_file.read_text()
        except Exception as e:
            logger.error(f"Failed to read output for {session_id}: {e}")

        return ""

    def get_error(self, session_id: str) -> str:
        """Read error output from session."""
        with self._lock:
            session = self.active_sessions.get(session_id)

        if not session or not session.error_file:
            return ""

        try:
            if session.error_file.exists():
                return session.error_file.read_text()
        except Exception as e:
            logger.error(f"Failed to read errors for {session_id}: {e}")

        return ""

    def terminate_session(self, session_id: str, force: bool = False):
        """
        Terminate a terminal session.

        Args:
            session_id: Session to terminate
            force: Use SIGKILL instead of SIGTERM
        """
        with self._lock:
            session = self.active_sessions.get(session_id)

        if not session:
            logger.warning(f"Session {session_id} not found")
            return

        try:
            if session.process:
                if force:
                    session.process.kill()
                else:
                    session.process.terminate()
                session.process.wait(timeout=5)
            elif session.pid:
                signal = 9 if force else 15
                os.kill(session.pid, signal)

            logger.info(f"Terminated session {session_id}")

        except Exception as e:
            logger.error(f"Error terminating session {session_id}: {e}")
        finally:
            with self._lock:
                if session_id in self.active_sessions:
                    del self.active_sessions[session_id]

    def list_active_sessions(self) -> List[Dict[str, Any]]:
        """Get list of all active sessions."""
        with self._lock:
            return [
                {
                    'session_id': sid,
                    'task_id': session.task_id,
                    'pid': session.pid,
                    'running': self.is_running(sid),
                    'runtime': time.time() - session.start_time
                }
                for sid, session in self.active_sessions.items()
            ]

    def cleanup_session(self, session_id: str):
        """Remove session and clean up resources."""
        with self._lock:
            session = self.active_sessions.get(session_id)

        if session:
            # Ensure process is terminated
            if self.is_running(session_id):
                self.terminate_session(session_id)

            # Clean up files (optional - keep for debugging)
            # if session.output_file and session.output_file.exists():
            #     session.output_file.unlink()
            # if session.error_file and session.error_file.exists():
            #     session.error_file.unlink()

            with self._lock:
                if session_id in self.active_sessions:
                    del self.active_sessions[session_id]

            logger.info(f"Cleaned up session {session_id}")

    def wait_for_completion(self, session_id: str, timeout: int = 600) -> bool:
        """
        Wait for session to complete.

        Args:
            session_id: Session to wait for
            timeout: Maximum time to wait in seconds

        Returns:
            True if completed successfully, False if timeout/error
        """
        start = time.time()

        while time.time() - start < timeout:
            if not self.is_running(session_id):
                return True
            time.sleep(1)

        logger.warning(f"Session {session_id} timed out after {timeout}s")
        return False

    def get_exit_code(self, session_id: str) -> Optional[int]:
        """Get exit code of completed session."""
        with self._lock:
            session = self.active_sessions.get(session_id)

        if session and session.process:
            return session.process.returncode

        return None
