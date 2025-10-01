"""
Configuration management for ZephyrOS Executor.
"""

import os
from typing import Optional
from dataclasses import dataclass
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


@dataclass
class ExecutorConfig:
    """Configuration for the executor."""

    # ZMemory API settings
    zmemory_api_url: str
    zmemory_api_key: str

    # Anthropic Claude API settings
    anthropic_api_key: str
    claude_model: str = "claude-sonnet-4-20250514"

    # Executor settings
    agent_name: str = "zephyr-executor-1"
    max_concurrent_tasks: int = 2
    polling_interval_seconds: int = 30

    # Resource limits
    max_tokens_per_request: int = 4096
    task_timeout_seconds: int = 600

    @classmethod
    def from_env(cls) -> "ExecutorConfig":
        """
        Create configuration from environment variables.

        Returns:
            ExecutorConfig instance

        Raises:
            ValueError: If required environment variables are missing
        """
        zmemory_api_url = os.getenv("ZMEMORY_API_URL")
        zmemory_api_key = os.getenv("ZMEMORY_API_KEY")
        anthropic_api_key = os.getenv("ANTHROPIC_API_KEY")

        # Check required variables
        missing = []
        if not zmemory_api_url:
            missing.append("ZMEMORY_API_URL")
        if not zmemory_api_key:
            missing.append("ZMEMORY_API_KEY")
        if not anthropic_api_key:
            missing.append("ANTHROPIC_API_KEY")

        if missing:
            raise ValueError(
                f"Missing required environment variables: {', '.join(missing)}\n"
                "Please create a .env file based on .env.example"
            )

        return cls(
            zmemory_api_url=zmemory_api_url,
            zmemory_api_key=zmemory_api_key,
            anthropic_api_key=anthropic_api_key,
            claude_model=os.getenv("CLAUDE_MODEL", "claude-sonnet-4-20250514"),
            agent_name=os.getenv("AGENT_NAME", "zephyr-executor-1"),
            max_concurrent_tasks=int(os.getenv("MAX_CONCURRENT_TASKS", "2")),
            polling_interval_seconds=int(os.getenv("POLLING_INTERVAL_SECONDS", "30")),
            max_tokens_per_request=int(os.getenv("MAX_TOKENS_PER_REQUEST", "4096")),
            task_timeout_seconds=int(os.getenv("TASK_TIMEOUT_SECONDS", "600"))
        )

    def validate(self) -> bool:
        """
        Validate configuration values.

        Returns:
            True if configuration is valid

        Raises:
            ValueError: If configuration values are invalid
        """
        if self.max_concurrent_tasks < 1 or self.max_concurrent_tasks > 10:
            raise ValueError("max_concurrent_tasks must be between 1 and 10")

        if self.polling_interval_seconds < 5:
            raise ValueError("polling_interval_seconds must be at least 5")

        if self.max_tokens_per_request < 100:
            raise ValueError("max_tokens_per_request must be at least 100")

        return True
