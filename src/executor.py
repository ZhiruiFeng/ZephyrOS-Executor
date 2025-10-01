"""
Task Executor - Core execution engine for ZephyrOS Executor.
Handles task polling, execution, and result reporting.
"""

import time
import logging
from typing import Dict, Any, Optional
from datetime import datetime
import threading
from queue import Queue, Empty

from zmemory_client import ZMemoryClient
from claude_client import ClaudeClient
from config import ExecutorConfig
from auth_manager import AuthTokenManager
from terminal_manager import TerminalSessionManager
from claude_code_executor import ClaudeCodeExecutor
from pathlib import Path

logger = logging.getLogger(__name__)


class TaskExecutor:
    """Manages task execution lifecycle."""

    def __init__(self, config: ExecutorConfig):
        """
        Initialize the task executor.

        Args:
            config: Executor configuration
        """
        self.config = config
        self.auth_manager = AuthTokenManager(config.supabase_url, config.supabase_anon_key)
        self.zmemory = ZMemoryClient(config.zmemory_api_url, auth_manager=self.auth_manager)
        self.claude = ClaudeClient(config.anthropic_api_key, config.claude_model)

        # Initialize terminal execution components if needed
        self.terminal_manager = None
        self.terminal_executor = None
        if config.execution_mode == "terminal":
            self.terminal_manager = TerminalSessionManager(
                claude_path=config.claude_code_path,
                show_window=config.show_terminal_window,
                terminal_app=config.terminal_app
            )
            self.terminal_executor = ClaudeCodeExecutor(
                workspace_base=Path(config.workspace_base_dir),
                terminal_manager=self.terminal_manager,
                max_execution_time=config.task_timeout_seconds,
                auto_cleanup=config.auto_cleanup_workspaces
            )

        self.running = False
        self.task_queue = Queue()
        self.active_tasks = {}
        self.stats = {
            'total_tasks': 0,
            'completed': 0,
            'failed': 0,
            'total_tokens': 0
        }

    def start(self):
        """Start the executor (polling and execution)."""
        if self.running:
            logger.warning("Executor already running")
            return

        logger.info("Starting ZephyrOS Executor...")

        # Test connections
        if not self._test_connections():
            raise RuntimeError("Failed to connect to required services")

        self.running = True

        # Start polling thread
        polling_thread = threading.Thread(target=self._polling_loop, daemon=True)
        polling_thread.start()

        # Start execution thread(s)
        for i in range(self.config.max_concurrent_tasks):
            exec_thread = threading.Thread(
                target=self._execution_loop,
                name=f"executor-{i}",
                daemon=True
            )
            exec_thread.start()

        logger.info(f"Executor started with {self.config.max_concurrent_tasks} worker(s)")

    def stop(self):
        """Stop the executor."""
        logger.info("Stopping executor...")
        self.running = False
        time.sleep(1)  # Give threads time to finish
        logger.info("Executor stopped")

    def _test_connections(self) -> bool:
        """
        Test connections to ZMemory and Claude APIs.

        Returns:
            True if both connections successful
        """
        logger.info("Testing ZMemory connection...")
        if not self.zmemory.test_connection():
            logger.error("Failed to connect to ZMemory API")
            return False
        logger.info("✓ ZMemory connection successful")

        logger.info("Testing Claude API connection...")
        if not self.claude.test_connection():
            logger.error("Failed to connect to Claude API")
            return False
        logger.info("✓ Claude API connection successful")

        return True

    def _polling_loop(self):
        """Background loop that polls ZMemory for new tasks."""
        logger.info(f"Starting polling loop (interval: {self.config.polling_interval_seconds}s)")

        while self.running:
            try:
                # Fetch pending tasks
                tasks = self.zmemory.get_pending_tasks(self.config.agent_name)

                if tasks:
                    logger.info(f"Found {len(tasks)} pending task(s)")
                    for task in tasks:
                        # Check if we have capacity
                        if len(self.active_tasks) < self.config.max_concurrent_tasks:
                            # Try to accept the task
                            task_id = task.get('id')
                            if self.zmemory.accept_task(task_id, self.config.agent_name):
                                self.task_queue.put(task)
                                logger.info(f"Task {task_id} added to queue")
                        else:
                            logger.debug("At max capacity, skipping task acceptance")
                            break

                # Sleep until next poll
                time.sleep(self.config.polling_interval_seconds)

            except Exception as e:
                logger.error(f"Error in polling loop: {e}")
                time.sleep(5)  # Brief sleep before retry

    def _execution_loop(self):
        """Background loop that executes tasks from the queue."""
        thread_name = threading.current_thread().name
        logger.info(f"Starting execution loop ({thread_name})")

        while self.running:
            try:
                # Get task from queue (with timeout to allow checking self.running)
                try:
                    task = self.task_queue.get(timeout=1)
                except Empty:
                    continue

                task_id = task.get('id')
                logger.info(f"[{thread_name}] Executing task {task_id}")

                # Execute the task
                self._execute_task(task)

                # Mark as done in queue
                self.task_queue.task_done()

            except Exception as e:
                logger.error(f"Error in execution loop ({thread_name}): {e}")

    def _execute_task(self, task: Dict[str, Any]):
        """
        Execute a single task.

        Args:
            task: Task object from ZMemory
        """
        task_id = task.get('id')
        task_description = task.get('description', '')
        task_context = task.get('context', {})

        start_time = datetime.utcnow()
        self.active_tasks[task_id] = {'start_time': start_time, 'task': task}
        self.stats['total_tasks'] += 1

        try:
            # Update status to in_progress
            self.zmemory.update_task_status(task_id, 'in_progress', progress=0)

            # Determine execution mode (check task-specific override first)
            execution_mode = task.get('execution_mode', self.config.execution_mode)

            if execution_mode == 'terminal':
                logger.info(f"Executing task {task_id} in terminal mode...")
                result = self._execute_in_terminal(task)
            else:
                logger.info(f"Executing task {task_id} via Claude API...")
                result = self.claude.execute_task(task_description, task_context)

            if result['success']:
                # Update statistics
                self.stats['completed'] += 1
                if 'usage' in result:
                    self.stats['total_tokens'] += result['usage'].get('total_tokens', 0)

                # Prepare result payload
                completion_result = {
                    'response': result.get('response', result.get('output', '')),
                    'usage': result.get('usage', {}),
                    'model': result.get('model', self.config.claude_model),
                    'execution_time_seconds': result.get('execution_time', (datetime.utcnow() - start_time).total_seconds()),
                    'artifacts': result.get('artifacts', []),
                    'execution_mode': execution_mode
                }

                # Complete task in ZMemory
                self.zmemory.complete_task(task_id, completion_result)

                logger.info(f"Task {task_id} completed successfully")
            else:
                # Task failed
                self.stats['failed'] += 1
                error_msg = result.get('error', 'Unknown error')
                self.zmemory.fail_task(task_id, error_msg)
                logger.error(f"Task {task_id} failed: {error_msg}")

        except Exception as e:
            self.stats['failed'] += 1
            error_msg = f"Execution error: {str(e)}"
            logger.error(f"Task {task_id} encountered error: {error_msg}")
            self.zmemory.fail_task(task_id, error_msg)

        finally:
            # Remove from active tasks
            if task_id in self.active_tasks:
                del self.active_tasks[task_id]

    def _execute_in_terminal(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """
        Execute task using Claude Code in terminal.

        Args:
            task: Task dictionary

        Returns:
            Result dictionary
        """
        if not self.terminal_executor:
            raise RuntimeError("Terminal executor not initialized. Set EXECUTION_MODE=terminal")

        # Progress callback for ZMemory updates
        def update_progress(task_id: str, progress: int):
            try:
                self.zmemory.update_task_status(task_id, 'in_progress', progress=progress)
            except Exception as e:
                logger.error(f"Failed to update progress: {e}")

        # Execute in terminal with monitoring
        task_id = task['id']
        result = self.terminal_executor.execute_task_in_terminal(task)

        return result

    def get_status(self) -> Dict[str, Any]:
        """
        Get current executor status.

        Returns:
            Status dictionary with execution statistics
        """
        return {
            'running': self.running,
            'active_tasks': len(self.active_tasks),
            'queued_tasks': self.task_queue.qsize(),
            'stats': self.stats.copy(),
            'config': {
                'agent_name': self.config.agent_name,
                'max_concurrent_tasks': self.config.max_concurrent_tasks,
                'polling_interval': self.config.polling_interval_seconds
            }
        }
