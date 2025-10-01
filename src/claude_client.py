"""
Claude API Client
Handles communication with Anthropic's Claude API for task execution.
"""

import anthropic
from typing import Dict, Any, Optional, List
import logging

logger = logging.getLogger(__name__)


class ClaudeClient:
    """Client for interacting with Claude API."""

    def __init__(self, api_key: str, model: str = "claude-sonnet-4-20250514"):
        """
        Initialize Claude client.

        Args:
            api_key: Anthropic API key
            model: Claude model to use
        """
        self.client = anthropic.Anthropic(api_key=api_key)
        self.model = model
        self.max_tokens = 4096

    def test_connection(self) -> bool:
        """
        Test connection to Claude API.

        Returns:
            True if connection successful, False otherwise
        """
        try:
            # Send a simple test message
            response = self.client.messages.create(
                model=self.model,
                max_tokens=10,
                messages=[{"role": "user", "content": "Hello"}]
            )
            return response.content is not None
        except Exception as e:
            logger.error(f"Claude API connection test failed: {e}")
            return False

    def execute_task(self, task_description: str, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Execute a task using Claude API.

        Args:
            task_description: Description of the task to execute
            context: Optional additional context for the task

        Returns:
            Dictionary containing execution results with keys:
            - success: bool
            - response: str (Claude's response)
            - usage: dict (token usage)
            - error: str (optional, if failed)
        """
        try:
            # Build the prompt
            prompt = self._build_prompt(task_description, context)

            logger.info(f"Sending task to Claude API (model: {self.model})")

            # Call Claude API
            response = self.client.messages.create(
                model=self.model,
                max_tokens=self.max_tokens,
                messages=[{"role": "user", "content": prompt}]
            )

            # Extract text content
            response_text = ""
            if response.content:
                for block in response.content:
                    if hasattr(block, 'text'):
                        response_text += block.text

            # Calculate costs (approximate)
            usage = {
                'input_tokens': response.usage.input_tokens,
                'output_tokens': response.usage.output_tokens,
                'total_tokens': response.usage.input_tokens + response.usage.output_tokens
            }

            logger.info(f"Task executed successfully. Tokens used: {usage['total_tokens']}")

            return {
                'success': True,
                'response': response_text,
                'usage': usage,
                'model': self.model
            }

        except anthropic.APIError as e:
            logger.error(f"Claude API error: {e}")
            return {
                'success': False,
                'error': str(e),
                'response': ''
            }
        except Exception as e:
            logger.error(f"Unexpected error during task execution: {e}")
            return {
                'success': False,
                'error': str(e),
                'response': ''
            }

    def _build_prompt(self, task_description: str, context: Optional[Dict[str, Any]] = None) -> str:
        """
        Build a prompt for Claude from task description and context.

        Args:
            task_description: The task to execute
            context: Optional additional context

        Returns:
            Formatted prompt string
        """
        prompt_parts = [
            "You are ZephyrOS Executor, an AI assistant that completes coding and development tasks.",
            "",
            "TASK:",
            task_description,
        ]

        if context:
            prompt_parts.extend([
                "",
                "ADDITIONAL CONTEXT:",
            ])
            for key, value in context.items():
                prompt_parts.append(f"{key}: {value}")

        prompt_parts.extend([
            "",
            "Please complete this task and provide detailed output including:",
            "1. Your approach and reasoning",
            "2. Any code or artifacts generated",
            "3. Next steps or recommendations",
        ])

        return "\n".join(prompt_parts)

    def stream_task_execution(self, task_description: str, context: Optional[Dict[str, Any]] = None):
        """
        Execute a task with streaming response (for future real-time UI updates).

        Args:
            task_description: Description of the task to execute
            context: Optional additional context

        Yields:
            Text chunks as they arrive from Claude
        """
        try:
            prompt = self._build_prompt(task_description, context)

            with self.client.messages.stream(
                model=self.model,
                max_tokens=self.max_tokens,
                messages=[{"role": "user", "content": prompt}]
            ) as stream:
                for text in stream.text_stream:
                    yield text

        except Exception as e:
            logger.error(f"Streaming execution error: {e}")
            yield f"Error: {str(e)}"
