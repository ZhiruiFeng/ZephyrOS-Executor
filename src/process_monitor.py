"""
Process Monitor
Monitors Claude Code processes for output, completion signals, and errors.
"""

import os
import logging
import threading
import time
from typing import Dict, Any, Optional, Callable, List
from pathlib import Path
from dataclasses import dataclass
from enum import Enum

logger = logging.getLogger(__name__)


class ProcessState(Enum):
    """Process execution states."""
    STARTING = "starting"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    TIMEOUT = "timeout"
    KILLED = "killed"


@dataclass
class ProcessMetrics:
    """Metrics for a monitored process."""
    pid: int
    start_time: float
    end_time: Optional[float] = None
    cpu_percent: float = 0.0
    memory_mb: float = 0.0
    output_lines: int = 0
    error_lines: int = 0
    exit_code: Optional[int] = None
    state: ProcessState = ProcessState.STARTING


class ProcessMonitor:
    """Monitors Claude Code processes and captures execution metrics."""

    def __init__(self, check_interval: float = 1.0):
        """
        Initialize process monitor.

        Args:
            check_interval: How often to check process status (seconds)
        """
        self.check_interval = check_interval
        self.monitored_processes: Dict[int, ProcessMetrics] = {}
        self._lock = threading.Lock()
        self._callbacks: Dict[int, List[Callable]] = {}

    def attach_to_process(self,
                         pid: int,
                         output_file: Optional[Path] = None,
                         error_file: Optional[Path] = None) -> ProcessMetrics:
        """
        Attach monitor to a process.

        Args:
            pid: Process ID to monitor
            output_file: Path to output log file
            error_file: Path to error log file

        Returns:
            ProcessMetrics object
        """
        metrics = ProcessMetrics(
            pid=pid,
            start_time=time.time()
        )

        with self._lock:
            self.monitored_processes[pid] = metrics
            self._callbacks[pid] = []

        logger.info(f"Attached to process {pid}")

        # Start monitoring thread
        monitor_thread = threading.Thread(
            target=self._monitor_loop,
            args=(pid, output_file, error_file),
            daemon=True
        )
        monitor_thread.start()

        return metrics

    def _monitor_loop(self,
                     pid: int,
                     output_file: Optional[Path],
                     error_file: Optional[Path]):
        """
        Background monitoring loop for a process.

        Args:
            pid: Process ID
            output_file: Output log file path
            error_file: Error log file path
        """
        logger.debug(f"Starting monitor loop for PID {pid}")

        last_output_size = 0
        last_error_size = 0

        while True:
            with self._lock:
                metrics = self.monitored_processes.get(pid)

            if not metrics:
                break

            try:
                # Check if process is still running
                if not self._is_process_alive(pid):
                    self._mark_completed(pid)
                    break

                # Update state
                if metrics.state == ProcessState.STARTING:
                    metrics.state = ProcessState.RUNNING

                # Collect resource metrics
                self._update_resource_metrics(pid, metrics)

                # Monitor output files
                if output_file and output_file.exists():
                    current_size = output_file.stat().st_size
                    if current_size > last_output_size:
                        new_content = self._read_new_content(
                            output_file,
                            last_output_size,
                            current_size
                        )
                        metrics.output_lines += new_content.count('\n')
                        last_output_size = current_size

                        # Trigger callbacks
                        self._trigger_callbacks(pid, 'output', new_content)

                if error_file and error_file.exists():
                    current_size = error_file.stat().st_size
                    if current_size > last_error_size:
                        new_content = self._read_new_content(
                            error_file,
                            last_error_size,
                            current_size
                        )
                        metrics.error_lines += new_content.count('\n')
                        last_error_size = current_size

                        # Trigger callbacks
                        self._trigger_callbacks(pid, 'error', new_content)

            except Exception as e:
                logger.error(f"Error monitoring PID {pid}: {e}")
                metrics.state = ProcessState.FAILED
                break

            time.sleep(self.check_interval)

        logger.debug(f"Monitor loop ended for PID {pid}")

    def _is_process_alive(self, pid: int) -> bool:
        """Check if a process is still alive."""
        try:
            os.kill(pid, 0)
            return True
        except OSError:
            return False

    def _mark_completed(self, pid: int):
        """Mark a process as completed and collect exit code."""
        with self._lock:
            metrics = self.monitored_processes.get(pid)

        if metrics:
            metrics.end_time = time.time()
            metrics.state = ProcessState.COMPLETED

            # Try to get exit code (platform-specific)
            try:
                # This won't work for all processes, depends on how they were spawned
                import subprocess
                result = subprocess.run(
                    ['echo', '$?'],
                    capture_output=True,
                    shell=True
                )
                # This is a simplified approach; actual exit code retrieval
                # depends on having process handle
            except:
                pass

            self._trigger_callbacks(pid, 'completed', metrics)

            logger.info(f"Process {pid} completed after {metrics.end_time - metrics.start_time:.2f}s")

    def _update_resource_metrics(self, pid: int, metrics: ProcessMetrics):
        """Update CPU and memory metrics for process."""
        try:
            # Use ps command to get resource usage
            import subprocess
            result = subprocess.run(
                ['ps', '-p', str(pid), '-o', '%cpu,%mem'],
                capture_output=True,
                text=True,
                timeout=1
            )

            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) > 1:
                    values = lines[1].split()
                    if len(values) >= 2:
                        metrics.cpu_percent = float(values[0])
                        metrics.memory_mb = float(values[1])

        except Exception as e:
            logger.debug(f"Could not update resource metrics for {pid}: {e}")

    def _read_new_content(self,
                         file_path: Path,
                         start_pos: int,
                         end_pos: int) -> str:
        """Read new content from file."""
        try:
            with open(file_path, 'r') as f:
                f.seek(start_pos)
                return f.read(end_pos - start_pos)
        except Exception as e:
            logger.error(f"Error reading {file_path}: {e}")
            return ""

    def _trigger_callbacks(self, pid: int, event_type: str, data: Any):
        """Trigger registered callbacks for process events."""
        with self._lock:
            callbacks = self._callbacks.get(pid, [])

        for callback in callbacks:
            try:
                callback(pid, event_type, data)
            except Exception as e:
                logger.error(f"Callback error for PID {pid}: {e}")

    def register_callback(self,
                         pid: int,
                         callback: Callable[[int, str, Any], None]):
        """
        Register a callback for process events.

        Args:
            pid: Process ID
            callback: Function(pid, event_type, data)
        """
        with self._lock:
            if pid not in self._callbacks:
                self._callbacks[pid] = []
            self._callbacks[pid].append(callback)

        logger.debug(f"Registered callback for PID {pid}")

    def stream_output(self,
                     pid: int,
                     output_file: Path,
                     callback: Callable[[str], None],
                     tail_lines: int = 10):
        """
        Stream output from a process file to callback.

        Args:
            pid: Process ID
            output_file: File to stream from
            callback: Function to call with new lines
            tail_lines: Number of initial lines to read
        """
        if not output_file.exists():
            logger.warning(f"Output file does not exist: {output_file}")
            return

        try:
            with open(output_file, 'r') as f:
                # Read last N lines initially
                lines = f.readlines()
                for line in lines[-tail_lines:]:
                    callback(line.rstrip())

                # Continue streaming new lines
                while self._is_process_alive(pid):
                    line = f.readline()
                    if line:
                        callback(line.rstrip())
                    else:
                        time.sleep(0.1)

        except Exception as e:
            logger.error(f"Error streaming output for PID {pid}: {e}")

    def detect_completion_signal(self,
                                 pid: int,
                                 output_file: Path,
                                 signal_patterns: List[str]) -> bool:
        """
        Detect completion by looking for signal patterns in output.

        Args:
            pid: Process ID
            output_file: Output file to scan
            signal_patterns: List of patterns that indicate completion

        Returns:
            True if any completion signal detected
        """
        if not output_file.exists():
            return False

        try:
            content = output_file.read_text()

            for pattern in signal_patterns:
                if pattern in content:
                    logger.info(f"Detected completion signal '{pattern}' for PID {pid}")
                    return True

        except Exception as e:
            logger.error(f"Error detecting completion signal: {e}")

        return False

    def handle_timeout(self, pid: int):
        """Mark process as timed out."""
        with self._lock:
            metrics = self.monitored_processes.get(pid)

        if metrics:
            metrics.state = ProcessState.TIMEOUT
            metrics.end_time = time.time()

            self._trigger_callbacks(pid, 'timeout', metrics)

            logger.warning(f"Process {pid} timed out")

    def handle_kill(self, pid: int):
        """Mark process as killed."""
        with self._lock:
            metrics = self.monitored_processes.get(pid)

        if metrics:
            metrics.state = ProcessState.KILLED
            metrics.end_time = time.time()

            self._trigger_callbacks(pid, 'killed', metrics)

            logger.info(f"Process {pid} was killed")

    def get_metrics(self, pid: int) -> Optional[ProcessMetrics]:
        """Get current metrics for a process."""
        with self._lock:
            return self.monitored_processes.get(pid)

    def get_all_metrics(self) -> Dict[int, ProcessMetrics]:
        """Get metrics for all monitored processes."""
        with self._lock:
            return self.monitored_processes.copy()

    def detach(self, pid: int):
        """Stop monitoring a process."""
        with self._lock:
            if pid in self.monitored_processes:
                del self.monitored_processes[pid]
            if pid in self._callbacks:
                del self._callbacks[pid]

        logger.info(f"Detached from process {pid}")

    def get_summary(self, pid: int) -> Optional[Dict[str, Any]]:
        """
        Get summary of process execution.

        Args:
            pid: Process ID

        Returns:
            Summary dictionary with metrics and state
        """
        metrics = self.get_metrics(pid)

        if not metrics:
            return None

        runtime = (metrics.end_time or time.time()) - metrics.start_time

        return {
            'pid': pid,
            'state': metrics.state.value,
            'runtime_seconds': runtime,
            'cpu_percent': metrics.cpu_percent,
            'memory_mb': metrics.memory_mb,
            'output_lines': metrics.output_lines,
            'error_lines': metrics.error_lines,
            'exit_code': metrics.exit_code
        }
