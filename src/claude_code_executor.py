"""
Claude Code Executor
Executes tasks using Claude Code CLI in terminal sessions with workspace management.
"""

import json
import logging
import time
import shutil
from typing import Dict, Any, Optional, List
from pathlib import Path
from datetime import datetime

from terminal_manager import TerminalSessionManager, TerminalSession

logger = logging.getLogger(__name__)


class ClaudeCodeExecutor:
    """Executes AI tasks using Claude Code CLI in isolated workspaces."""

    def __init__(self,
                 workspace_base: Path,
                 terminal_manager: TerminalSessionManager,
                 max_execution_time: int = 600,
                 auto_cleanup: bool = True):
        """
        Initialize Claude Code Executor.

        Args:
            workspace_base: Base directory for task workspaces
            terminal_manager: Terminal session manager instance
            max_execution_time: Maximum task execution time in seconds
            auto_cleanup: Automatically cleanup workspaces after completion
        """
        self.workspace_base = Path(workspace_base)
        self.terminal_manager = terminal_manager
        self.max_execution_time = max_execution_time
        self.auto_cleanup = auto_cleanup

        # Ensure base directory exists
        self.workspace_base.mkdir(parents=True, exist_ok=True)

        logger.info(f"Claude Code Executor initialized (workspace: {self.workspace_base})")

    def execute_task_in_terminal(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """
        Execute a task using Claude Code in a terminal.

        Args:
            task: Task dictionary with id, description, context, files, etc.

        Returns:
            Execution result dictionary with success, output, artifacts, etc.
        """
        task_id = task['id']
        task_description = task.get('description', '')
        task_context = task.get('context', {})
        task_files = task.get('files', {})

        logger.info(f"Starting terminal execution for task {task_id}")

        start_time = time.time()
        workspace = None
        session = None

        try:
            # 1. Create isolated workspace
            workspace = self.create_workspace(task_id)
            logger.info(f"Created workspace: {workspace}")

            # 2. Prepare workspace with task files and context
            self.prepare_workspace(workspace, task_files, task_context)

            # 3. Format task prompt for Claude Code
            task_prompt = self.format_task_prompt(task_description, task_context)

            # 4. Spawn terminal session
            session = self.terminal_manager.spawn_terminal(
                task_id=task_id,
                workspace=workspace,
                task_prompt=task_prompt,
                timeout=self.max_execution_time
            )

            # 5. Monitor execution
            completed = self.monitor_execution(
                session=session,
                task_id=task_id,
                timeout=self.max_execution_time
            )

            if not completed:
                raise TimeoutError(f"Task {task_id} exceeded maximum execution time")

            # 6. Collect results
            output = self.terminal_manager.get_output(session.id)
            error = self.terminal_manager.get_error(session.id)
            artifacts = self.collect_artifacts(workspace)
            exit_code = self.terminal_manager.get_exit_code(session.id)

            execution_time = time.time() - start_time

            # Determine success
            success = exit_code == 0 or exit_code is None

            result = {
                'success': success,
                'output': output,
                'error': error if error else None,
                'artifacts': artifacts,
                'execution_time': execution_time,
                'exit_code': exit_code,
                'workspace': str(workspace),
                'session_id': session.id
            }

            logger.info(f"Task {task_id} completed: success={success}, time={execution_time:.2f}s")

            return result

        except Exception as e:
            logger.error(f"Error executing task {task_id}: {e}")
            return {
                'success': False,
                'error': str(e),
                'output': '',
                'artifacts': [],
                'execution_time': time.time() - start_time
            }

        finally:
            # Cleanup
            if session:
                self.terminal_manager.terminate_session(session.id)
                self.terminal_manager.cleanup_session(session.id)

            if workspace and self.auto_cleanup:
                self.cleanup_workspace(workspace)

    def create_workspace(self, task_id: str) -> Path:
        """
        Create isolated workspace for task execution.

        Args:
            task_id: Unique task identifier

        Returns:
            Path to created workspace
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        workspace = self.workspace_base / f"{task_id}_{timestamp}"

        workspace.mkdir(parents=True, exist_ok=True)

        # Create subdirectories
        (workspace / "input").mkdir(exist_ok=True)
        (workspace / "output").mkdir(exist_ok=True)
        (workspace / "logs").mkdir(exist_ok=True)

        # Create .claude directory for configuration
        claude_dir = workspace / ".claude"
        claude_dir.mkdir(exist_ok=True)

        # Write Claude Code settings
        settings = {
            "model": "claude-sonnet-4-5",
            "max_tokens": 100000,
            "temperature": 0,
            "auto_approve": False  # Require approval for safety
        }

        settings_file = claude_dir / "settings.json"
        with open(settings_file, 'w') as f:
            json.dump(settings, f, indent=2)

        logger.debug(f"Created workspace structure at {workspace}")

        return workspace

    def prepare_workspace(self,
                         workspace: Path,
                         files: Dict[str, str],
                         context: Dict[str, Any]):
        """
        Prepare workspace with task files and context.

        Args:
            workspace: Workspace directory
            files: Dictionary of filename -> content
            context: Additional task context
        """
        # Write task files to input directory
        input_dir = workspace / "input"

        for filename, content in files.items():
            file_path = input_dir / filename

            # Create parent directories if needed
            file_path.parent.mkdir(parents=True, exist_ok=True)

            with open(file_path, 'w') as f:
                f.write(content)

            logger.debug(f"Wrote file: {file_path}")

        # Write context to JSON file
        if context:
            context_file = workspace / "task_context.json"
            with open(context_file, 'w') as f:
                json.dump(context, f, indent=2)

            logger.debug(f"Wrote context to {context_file}")

    def format_task_prompt(self,
                          description: str,
                          context: Optional[Dict[str, Any]] = None) -> str:
        """
        Format task description and context into Claude Code prompt.

        Args:
            description: Task description
            context: Optional additional context

        Returns:
            Formatted prompt string
        """
        prompt_parts = [
            "You are ZephyrOS Executor running via Claude Code.",
            "",
            "TASK:",
            description,
            ""
        ]

        if context:
            prompt_parts.append("CONTEXT:")
            for key, value in context.items():
                prompt_parts.append(f"- {key}: {value}")
            prompt_parts.append("")

        prompt_parts.extend([
            "WORKSPACE STRUCTURE:",
            "- ./input/       : Input files provided for this task",
            "- ./output/      : Place any generated files here",
            "- ./logs/        : Place any log files here",
            "",
            "INSTRUCTIONS:",
            "1. Review the task and any input files",
            "2. Complete the requested work",
            "3. Save results to ./output/ directory",
            "4. Provide a summary of what you accomplished",
            "",
            "Please begin the task now."
        ])

        return "\n".join(prompt_parts)

    def monitor_execution(self,
                         session: TerminalSession,
                         task_id: str,
                         timeout: int,
                         progress_callback: Optional[callable] = None) -> bool:
        """
        Monitor task execution and optionally report progress.

        Args:
            session: Terminal session to monitor
            task_id: Task identifier
            timeout: Maximum execution time
            progress_callback: Optional callback(task_id, progress_percent)

        Returns:
            True if completed within timeout, False otherwise
        """
        start_time = time.time()
        last_output_size = 0

        logger.info(f"Monitoring execution of task {task_id} (timeout: {timeout}s)")

        while time.time() - start_time < timeout:
            # Check if session is still running
            if not self.terminal_manager.is_running(session.id):
                logger.info(f"Task {task_id} session completed")
                return True

            # Read output to detect progress (optional)
            if progress_callback:
                output = self.terminal_manager.get_output(session.id)
                output_size = len(output)

                if output_size > last_output_size:
                    # Calculate rough progress based on output growth
                    elapsed = time.time() - start_time
                    progress = min(int((elapsed / timeout) * 100), 95)

                    progress_callback(task_id, progress)
                    last_output_size = output_size

            time.sleep(2)  # Check every 2 seconds

        # Timeout reached
        logger.warning(f"Task {task_id} timed out after {timeout}s")
        return False

    def collect_artifacts(self, workspace: Path) -> List[Dict[str, Any]]:
        """
        Collect generated artifacts from workspace.

        Args:
            workspace: Workspace directory

        Returns:
            List of artifact dictionaries with name, path, size, type
        """
        artifacts = []
        output_dir = workspace / "output"

        if not output_dir.exists():
            return artifacts

        try:
            for file_path in output_dir.rglob("*"):
                if file_path.is_file():
                    relative_path = file_path.relative_to(output_dir)

                    artifact = {
                        'name': file_path.name,
                        'path': str(relative_path),
                        'full_path': str(file_path),
                        'size': file_path.stat().st_size,
                        'type': file_path.suffix or 'unknown'
                    }

                    # Read small text files
                    if artifact['size'] < 100_000 and file_path.suffix in ['.txt', '.json', '.md', '.log']:
                        try:
                            artifact['content'] = file_path.read_text()
                        except:
                            pass  # Binary or encoding issue

                    artifacts.append(artifact)

            logger.info(f"Collected {len(artifacts)} artifact(s) from {output_dir}")

        except Exception as e:
            logger.error(f"Error collecting artifacts: {e}")

        return artifacts

    def cleanup_workspace(self, workspace: Path):
        """
        Clean up workspace directory.

        Args:
            workspace: Workspace directory to remove
        """
        try:
            if workspace.exists():
                shutil.rmtree(workspace)
                logger.info(f"Cleaned up workspace: {workspace}")
        except Exception as e:
            logger.error(f"Failed to cleanup workspace {workspace}: {e}")

    def list_workspaces(self) -> List[Dict[str, Any]]:
        """
        List all workspace directories.

        Returns:
            List of workspace info dictionaries
        """
        workspaces = []

        try:
            for workspace_dir in self.workspace_base.iterdir():
                if workspace_dir.is_dir():
                    workspaces.append({
                        'path': str(workspace_dir),
                        'name': workspace_dir.name,
                        'created': workspace_dir.stat().st_ctime,
                        'size': sum(f.stat().st_size for f in workspace_dir.rglob('*') if f.is_file())
                    })
        except Exception as e:
            logger.error(f"Error listing workspaces: {e}")

        return workspaces

    def cleanup_old_workspaces(self, max_age_hours: int = 24):
        """
        Remove workspace directories older than specified age.

        Args:
            max_age_hours: Maximum age in hours
        """
        max_age_seconds = max_age_hours * 3600
        current_time = time.time()
        removed_count = 0

        try:
            for workspace_dir in self.workspace_base.iterdir():
                if workspace_dir.is_dir():
                    age = current_time - workspace_dir.stat().st_ctime

                    if age > max_age_seconds:
                        shutil.rmtree(workspace_dir)
                        removed_count += 1
                        logger.debug(f"Removed old workspace: {workspace_dir.name}")

            if removed_count > 0:
                logger.info(f"Cleaned up {removed_count} old workspace(s)")

        except Exception as e:
            logger.error(f"Error cleaning old workspaces: {e}")
