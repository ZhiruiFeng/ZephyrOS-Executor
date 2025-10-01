"""
CLI interface for ZephyrOS Executor.
"""

import sys
import time
import signal
import asyncio
from typing import Optional
from colorama import init, Fore, Style

from config import ExecutorConfig
from executor import TaskExecutor
from auth_manager import AuthTokenManager

# Initialize colorama for cross-platform colored output
init()


class ExecutorCLI:
    """Command-line interface for the executor."""

    def __init__(self):
        self.executor: Optional[TaskExecutor] = None
        self.running = False

    def print_banner(self):
        """Print application banner."""
        banner = f"""
{Fore.CYAN}╔═══════════════════════════════════════════════════════╗
║                                                       ║
║           {Fore.WHITE}ZephyrOS Executor v0.1.0{Fore.CYAN}                ║
║        {Fore.WHITE}Local AI Task Execution Engine{Fore.CYAN}             ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝{Style.RESET_ALL}
"""
        print(banner)

    def print_status(self, message: str, status: str = "info"):
        """Print status message with color coding."""
        colors = {
            "info": Fore.CYAN,
            "success": Fore.GREEN,
            "warning": Fore.YELLOW,
            "error": Fore.RED
        }
        color = colors.get(status, Fore.WHITE)
        print(f"{color}► {message}{Style.RESET_ALL}")

    def print_stats(self):
        """Print current execution statistics."""
        if not self.executor:
            return

        status = self.executor.get_status()
        stats = status['stats']

        print(f"\n{Fore.CYAN}═══ Statistics ═══{Style.RESET_ALL}")
        print(f"  {Fore.WHITE}Status:{Style.RESET_ALL} {Fore.GREEN if status['running'] else Fore.RED}{'Running' if status['running'] else 'Stopped'}{Style.RESET_ALL}")
        print(f"  {Fore.WHITE}Active Tasks:{Style.RESET_ALL} {status['active_tasks']}")
        print(f"  {Fore.WHITE}Queued Tasks:{Style.RESET_ALL} {status['queued_tasks']}")
        print(f"  {Fore.WHITE}Total Tasks:{Style.RESET_ALL} {stats['total_tasks']}")
        print(f"  {Fore.WHITE}Completed:{Style.RESET_ALL} {Fore.GREEN}{stats['completed']}{Style.RESET_ALL}")
        print(f"  {Fore.WHITE}Failed:{Style.RESET_ALL} {Fore.RED}{stats['failed']}{Style.RESET_ALL}")
        print(f"  {Fore.WHITE}Total Tokens:{Style.RESET_ALL} {stats['total_tokens']:,}")
        if stats['total_tasks'] > 0:
            success_rate = (stats['completed'] / stats['total_tasks']) * 100
            print(f"  {Fore.WHITE}Success Rate:{Style.RESET_ALL} {success_rate:.1f}%")
        print()

    def handle_sigint(self, signum, frame):
        """Handle Ctrl+C gracefully."""
        print(f"\n{Fore.YELLOW}Received interrupt signal...{Style.RESET_ALL}")
        self.stop()
        sys.exit(0)

    def run(self):
        """Run the executor CLI."""
        # Register signal handler for graceful shutdown
        signal.signal(signal.SIGINT, self.handle_sigint)

        self.print_banner()

        # Load configuration
        try:
            self.print_status("Loading configuration...", "info")
            config = ExecutorConfig.from_env()
            config.validate()
            self.print_status(f"Configuration loaded (Agent: {config.agent_name})", "success")
        except ValueError as e:
            self.print_status(f"Configuration error: {e}", "error")
            return 1
        except Exception as e:
            self.print_status(f"Failed to load configuration: {e}", "error")
            return 1

        # Initialize executor
        try:
            self.print_status("Initializing executor...", "info")
            self.executor = TaskExecutor(config)
            self.print_status("Executor initialized", "success")
        except Exception as e:
            self.print_status(f"Failed to initialize executor: {e}", "error")
            return 1

        # Start executor
        try:
            self.print_status("Starting executor...", "info")
            self.executor.start()
            self.running = True
            self.print_status("Executor started successfully!", "success")
            print(f"\n{Fore.GREEN}✓{Style.RESET_ALL} {Fore.WHITE}Executor is now running and polling for tasks{Style.RESET_ALL}")
            print(f"{Fore.CYAN}  Press Ctrl+C to stop{Style.RESET_ALL}\n")
        except RuntimeError as e:
            self.print_status(f"Failed to start: {e}", "error")
            return 1
        except Exception as e:
            self.print_status(f"Unexpected error: {e}", "error")
            return 1

        # Main loop - print stats periodically
        try:
            stats_interval = 30  # Print stats every 30 seconds
            last_stats_time = time.time()

            while self.running:
                time.sleep(1)

                # Print stats periodically
                if time.time() - last_stats_time >= stats_interval:
                    self.print_stats()
                    last_stats_time = time.time()

        except KeyboardInterrupt:
            pass
        finally:
            self.stop()

        return 0

    def stop(self):
        """Stop the executor."""
        if self.executor and self.running:
            self.print_status("Stopping executor...", "warning")
            self.executor.stop()
            self.running = False
            self.print_stats()
            self.print_status("Executor stopped", "success")


def login():
    """Login command to authenticate with Google OAuth."""
    print(f"{Fore.CYAN}╔═══════════════════════════════════════════════════════╗")
    print(f"║     {Fore.WHITE}ZephyrOS Executor - Google Login{Fore.CYAN}           ║")
    print(f"╚═══════════════════════════════════════════════════════╝{Style.RESET_ALL}\n")

    try:
        # Load config
        config = ExecutorConfig.from_env()
        auth_manager = AuthTokenManager(config.supabase_url, config.supabase_anon_key)

        # Check if user wants to provide a token directly
        if len(sys.argv) > 2 and sys.argv[2] == '--token':
            if len(sys.argv) < 4:
                print(f"{Fore.RED}Error: --token requires an access token argument{Style.RESET_ALL}")
                return 1

            access_token = sys.argv[3]
            print(f"{Fore.CYAN}Setting session from provided token...{Style.RESET_ALL}")

            if auth_manager.set_session_from_token(access_token):
                print(f"{Fore.GREEN}✓ Login successful!{Style.RESET_ALL}\n")

                # Get user info
                user_info = auth_manager.get_user_info()
                if user_info:
                    print(f"Logged in as: {user_info.get('email', 'unknown')}")
                    print(f"User ID: {user_info.get('id', 'unknown')}\n")

                return 0
            else:
                print(f"{Fore.RED}✗ Login failed{Style.RESET_ALL}")
                return 1
        else:
            # OAuth flow
            print(f"{Fore.YELLOW}Starting Google OAuth login...{Style.RESET_ALL}\n")
            asyncio.run(auth_manager.login_with_google_oauth())
            print(f"\n{Fore.CYAN}After completing authentication in your browser:{Style.RESET_ALL}")
            print(f"1. Copy the access_token from the callback URL")
            print(f"2. Run: {Fore.WHITE}python -m src.cli login --token <your_token>{Style.RESET_ALL}\n")
            return 0

    except Exception as e:
        print(f"{Fore.RED}Error: {e}{Style.RESET_ALL}")
        return 1


def logout():
    """Logout command to clear authentication."""
    print(f"{Fore.CYAN}Logging out...{Style.RESET_ALL}")

    try:
        config = ExecutorConfig.from_env()
        auth_manager = AuthTokenManager(config.supabase_url, config.supabase_anon_key)
        auth_manager.logout()
        print(f"{Fore.GREEN}✓ Logged out successfully{Style.RESET_ALL}")
        return 0
    except Exception as e:
        print(f"{Fore.RED}Error: {e}{Style.RESET_ALL}")
        return 1


def whoami():
    """Show current authenticated user."""
    try:
        config = ExecutorConfig.from_env()
        auth_manager = AuthTokenManager(config.supabase_url, config.supabase_anon_key)

        user_info = auth_manager.get_user_info()
        if user_info:
            print(f"\n{Fore.GREEN}Authenticated as:{Style.RESET_ALL}")
            print(f"  Email: {user_info.get('email', 'unknown')}")
            print(f"  User ID: {user_info.get('id', 'unknown')}")
            print(f"  Provider: {user_info.get('provider', 'unknown')}\n")
            return 0
        else:
            print(f"{Fore.YELLOW}Not logged in{Style.RESET_ALL}")
            print(f"Run: {Fore.WHITE}python -m src.cli login{Style.RESET_ALL}\n")
            return 1
    except Exception as e:
        print(f"{Fore.RED}Error: {e}{Style.RESET_ALL}")
        return 1


def main():
    """Main entry point for the CLI."""
    # Check for subcommands
    if len(sys.argv) > 1:
        command = sys.argv[1]
        if command == 'login':
            sys.exit(login())
        elif command == 'logout':
            sys.exit(logout())
        elif command == 'whoami':
            sys.exit(whoami())
        elif command in ['--help', '-h', 'help']:
            print(f"\n{Fore.CYAN}ZephyrOS Executor CLI{Style.RESET_ALL}\n")
            print("Commands:")
            print(f"  {Fore.WHITE}python -m src.cli{Style.RESET_ALL}                    - Run the executor")
            print(f"  {Fore.WHITE}python -m src.cli login{Style.RESET_ALL}              - Login with Google OAuth")
            print(f"  {Fore.WHITE}python -m src.cli login --token <token>{Style.RESET_ALL} - Login with access token")
            print(f"  {Fore.WHITE}python -m src.cli logout{Style.RESET_ALL}             - Logout")
            print(f"  {Fore.WHITE}python -m src.cli whoami{Style.RESET_ALL}             - Show current user")
            print()
            return 0
        else:
            print(f"{Fore.RED}Unknown command: {command}{Style.RESET_ALL}")
            print(f"Run '{Fore.WHITE}python -m src.cli --help{Style.RESET_ALL}' for usage")
            return 1

    # No command - run executor
    cli = ExecutorCLI()
    sys.exit(cli.run())


if __name__ == "__main__":
    main()
