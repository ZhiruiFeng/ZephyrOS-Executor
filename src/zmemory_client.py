"""
ZMemory API Client
Handles communication with the ZMemory backend API.
"""

import requests
from typing import List, Dict, Optional, Any
from datetime import datetime
import logging
import asyncio

logger = logging.getLogger(__name__)


class ZMemoryClient:
    """Client for interacting with ZMemory API."""

    def __init__(self, api_url: str, auth_manager=None):
        """
        Initialize ZMemory client.

        Args:
            api_url: Base URL for ZMemory API
            auth_manager: Optional AuthTokenManager instance for authentication
        """
        self.api_url = api_url.rstrip('/')
        self.auth_manager = auth_manager
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json'
        })

    async def _get_auth_headers(self) -> Dict[str, str]:
        """Get current authentication headers."""
        if self.auth_manager:
            return await self.auth_manager.get_auth_headers()
        return {}

    def _make_request(self, method: str, url: str, **kwargs) -> requests.Response:
        """Make authenticated HTTP request."""
        # Get auth headers synchronously
        headers = asyncio.run(self._get_auth_headers())

        # Merge with any existing headers
        if 'headers' in kwargs:
            headers.update(kwargs['headers'])
        kwargs['headers'] = headers

        return self.session.request(method, url, **kwargs)

    def test_connection(self) -> bool:
        """
        Test connection to ZMemory API.

        Returns:
            True if connection successful, False otherwise
        """
        try:
            response = self._make_request('GET', f'{self.api_url}/health')
            return response.status_code == 200
        except Exception as e:
            logger.error(f"Connection test failed: {e}")
            return False

    def get_pending_tasks(self, agent_name: str) -> List[Dict[str, Any]]:
        """
        Fetch pending tasks from ZMemory.

        Args:
            agent_name: Name of the agent requesting tasks

        Returns:
            List of pending task objects
        """
        try:
            response = self._make_request(
                'GET',
                f'{self.api_url}/tasks/pending',
                params={'agent': agent_name}
            )
            response.raise_for_status()
            return response.json().get('tasks', [])
        except requests.RequestException as e:
            logger.error(f"Failed to fetch pending tasks: {e}")
            return []

    def accept_task(self, task_id: str, agent_name: str) -> bool:
        """
        Accept a task for execution.

        Args:
            task_id: ID of the task to accept
            agent_name: Name of the agent accepting the task

        Returns:
            True if task accepted successfully
        """
        try:
            response = self._make_request(
                'POST',
                f'{self.api_url}/tasks/{task_id}/accept',
                json={'agent': agent_name}
            )
            response.raise_for_status()
            logger.info(f"Task {task_id} accepted successfully")
            return True
        except requests.RequestException as e:
            logger.error(f"Failed to accept task {task_id}: {e}")
            return False

    def update_task_status(self, task_id: str, status: str, progress: Optional[int] = None) -> bool:
        """
        Update task status in ZMemory.

        Args:
            task_id: ID of the task
            status: New status (e.g., 'in_progress', 'completed', 'failed')
            progress: Optional progress percentage (0-100)

        Returns:
            True if update successful
        """
        try:
            data = {'status': status}
            if progress is not None:
                data['progress'] = progress

            response = self._make_request(
                'PATCH',
                f'{self.api_url}/tasks/{task_id}/status',
                json=data
            )
            response.raise_for_status()
            logger.info(f"Task {task_id} status updated to {status}")
            return True
        except requests.RequestException as e:
            logger.error(f"Failed to update task {task_id} status: {e}")
            return False

    def complete_task(self, task_id: str, result: Dict[str, Any]) -> bool:
        """
        Mark task as completed and submit results.

        Args:
            task_id: ID of the task
            result: Task execution results

        Returns:
            True if completion successful
        """
        try:
            response = self._make_request(
                'POST',
                f'{self.api_url}/tasks/{task_id}/complete',
                json={
                    'result': result,
                    'completed_at': datetime.utcnow().isoformat()
                }
            )
            response.raise_for_status()
            logger.info(f"Task {task_id} completed successfully")
            return True
        except requests.RequestException as e:
            logger.error(f"Failed to complete task {task_id}: {e}")
            return False

    def fail_task(self, task_id: str, error: str) -> bool:
        """
        Mark task as failed with error details.

        Args:
            task_id: ID of the task
            error: Error message or details

        Returns:
            True if update successful
        """
        try:
            response = self._make_request(
                'POST',
                f'{self.api_url}/tasks/{task_id}/fail',
                json={
                    'error': error,
                    'failed_at': datetime.utcnow().isoformat()
                }
            )
            response.raise_for_status()
            logger.warning(f"Task {task_id} marked as failed: {error}")
            return True
        except requests.RequestException as e:
            logger.error(f"Failed to mark task {task_id} as failed: {e}")
            return False

    def upload_artifact(self, task_id: str, artifact_name: str, content: str) -> bool:
        """
        Upload task artifact to ZMemory.

        Args:
            task_id: ID of the task
            artifact_name: Name of the artifact file
            content: Artifact content

        Returns:
            True if upload successful
        """
        try:
            response = self._make_request(
                'POST',
                f'{self.api_url}/tasks/{task_id}/artifacts',
                json={
                    'name': artifact_name,
                    'content': content
                }
            )
            response.raise_for_status()
            logger.info(f"Artifact {artifact_name} uploaded for task {task_id}")
            return True
        except requests.RequestException as e:
            logger.error(f"Failed to upload artifact {artifact_name}: {e}")
            return False
