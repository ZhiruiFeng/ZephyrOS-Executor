"""
Supabase Authentication Manager for ZephyrOS Executor.
Handles OAuth device flow and session token management.
"""

import json
import time
import webbrowser
import logging
from pathlib import Path
from typing import Optional, Dict, Any
from datetime import datetime, timedelta
from supabase import create_client, Client
import httpx

logger = logging.getLogger(__name__)


class AuthTokenManager:
    """Manages Supabase authentication tokens with device flow OAuth."""

    # Token cache file location
    TOKEN_CACHE_FILE = Path.home() / ".zephyros" / "executor_auth.json"

    def __init__(self, supabase_url: str, supabase_anon_key: str):
        """
        Initialize the auth manager.

        Args:
            supabase_url: Supabase project URL
            supabase_anon_key: Supabase anonymous key
        """
        self.supabase_url = supabase_url
        self.supabase_anon_key = supabase_anon_key
        self.supabase: Optional[Client] = None
        self.cached_token: Optional[str] = None
        self.token_expiry: Optional[datetime] = None
        self._initialize_supabase()

    def _initialize_supabase(self):
        """Initialize Supabase client."""
        try:
            self.supabase = create_client(
                self.supabase_url,
                self.supabase_anon_key
            )
            logger.info("✓ Supabase client initialized")
        except Exception as e:
            logger.error(f"Failed to initialize Supabase client: {e}")
            raise

    def _load_cached_session(self) -> Optional[Dict[str, Any]]:
        """Load cached session from file."""
        try:
            if self.TOKEN_CACHE_FILE.exists():
                with open(self.TOKEN_CACHE_FILE, 'r') as f:
                    data = json.load(f)
                    # Check if token is still valid
                    expiry = datetime.fromisoformat(data.get('expires_at', ''))
                    if expiry > datetime.now():
                        logger.info("✓ Loaded valid cached session")
                        return data
                    else:
                        logger.info("Cached session expired")
        except Exception as e:
            logger.warning(f"Failed to load cached session: {e}")
        return None

    def _save_session(self, session: Dict[str, Any]):
        """Save session to cache file."""
        try:
            self.TOKEN_CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
            with open(self.TOKEN_CACHE_FILE, 'w') as f:
                json.dump(session, f, indent=2)
            logger.info("✓ Session cached successfully")
        except Exception as e:
            logger.warning(f"Failed to cache session: {e}")

    def _clear_cached_session(self):
        """Clear cached session file."""
        try:
            if self.TOKEN_CACHE_FILE.exists():
                self.TOKEN_CACHE_FILE.unlink()
                logger.info("✓ Cached session cleared")
        except Exception as e:
            logger.warning(f"Failed to clear cached session: {e}")

    async def login_with_google_oauth(self) -> bool:
        """
        Perform OAuth device flow login with Google.

        Returns:
            True if login successful
        """
        try:
            logger.info("🔐 Starting Google OAuth login flow...")

            # Sign in with OAuth using redirect flow
            # Supabase handles the OAuth flow through a browser redirect
            response = self.supabase.auth.sign_in_with_oauth({
                "provider": "google",
                "options": {
                    "redirect_to": "http://localhost:54321/auth/callback"
                }
            })

            if response and response.url:
                logger.info(f"\n{'='*60}")
                logger.info("Please complete authentication in your browser:")
                logger.info(f"URL: {response.url}")
                logger.info(f"{'='*60}\n")

                # Open browser automatically
                webbrowser.open(response.url)

                # Wait for callback (in production, we'd set up a local server)
                logger.info("Waiting for authentication callback...")
                logger.info("After logging in, please copy the access_token from the URL")
                logger.info("and run: python -m src.cli login --token <your_token>")

                return True
            else:
                logger.error("Failed to initiate OAuth flow")
                return False

        except Exception as e:
            logger.error(f"OAuth login failed: {e}")
            return False

    def set_session_from_token(self, access_token: str, refresh_token: Optional[str] = None) -> bool:
        """
        Set session from provided tokens.

        Args:
            access_token: JWT access token
            refresh_token: Optional refresh token

        Returns:
            True if session set successfully
        """
        try:
            # Set the session in Supabase client
            response = self.supabase.auth.set_session(access_token, refresh_token or "")

            if response and response.session:
                # Cache the session
                session_data = {
                    "access_token": response.session.access_token,
                    "refresh_token": response.session.refresh_token,
                    "expires_at": datetime.fromtimestamp(response.session.expires_at).isoformat() if response.session.expires_at else None,
                    "user_id": response.session.user.id if response.session.user else None
                }
                self._save_session(session_data)

                self.cached_token = response.session.access_token
                if response.session.expires_at:
                    self.token_expiry = datetime.fromtimestamp(response.session.expires_at)

                logger.info(f"✓ Session set successfully for user: {response.session.user.id if response.session.user else 'unknown'}")
                return True
            else:
                logger.error("Failed to set session from token")
                return False

        except Exception as e:
            logger.error(f"Failed to set session from token: {e}")
            return False

    async def get_valid_token(self) -> Optional[str]:
        """
        Get a valid access token, refreshing if necessary.

        Returns:
            Valid access token or None if not authenticated
        """
        # Check cached token first
        if self.cached_token and self.token_expiry:
            if datetime.now() < self.token_expiry - timedelta(minutes=5):
                # Validate the token before returning it
                if await self._validate_token(self.cached_token):
                    return self.cached_token
                else:
                    logger.warning("Cached token is invalid, attempting to refresh...")

        # Try to load from cache file
        cached_session = self._load_cached_session()
        if cached_session:
            try:
                # Restore session
                response = self.supabase.auth.set_session(
                    cached_session['access_token'],
                    cached_session.get('refresh_token', '')
                )
                if response and response.session:
                    # Validate the restored session
                    if await self._validate_token(response.session.access_token):
                        self.cached_token = response.session.access_token
                        self.token_expiry = datetime.fromtimestamp(response.session.expires_at) if response.session.expires_at else None
                        return self.cached_token
                    else:
                        logger.warning("Restored session token is invalid")
                        self._clear_cached_session()
            except Exception as e:
                logger.warning(f"Failed to restore session: {e}")
                self._clear_cached_session()

        # Try to refresh the session
        try:
            response = self.supabase.auth.get_session()
            if response and response.access_token:
                # Validate the refreshed token
                if await self._validate_token(response.access_token):
                    self.cached_token = response.access_token
                    # Update cache
                    session_data = self._load_cached_session() or {}
                    session_data['access_token'] = response.access_token
                    self._save_session(session_data)
                    return self.cached_token
        except Exception as e:
            logger.warning(f"Failed to refresh session: {e}")

        # No valid session - clear cache and require re-login
        self._clear_cached_session()
        logger.warning("⚠️  No valid authentication session. Please run: python -m src.cli login")
        return None

    async def _validate_token(self, token: str) -> bool:
        """
        Validate a token by making a test API call.

        Args:
            token: The token to validate

        Returns:
            True if token is valid, False otherwise
        """
        try:
            # Try to get user info with the token
            url = f"{self.supabase_url}/auth/v1/user"
            headers = {
                "Authorization": f"Bearer {token}",
                "apikey": self.supabase_anon_key
            }

            async with httpx.AsyncClient() as client:
                response = await client.get(url, headers=headers, timeout=10.0)
                return response.status_code == 200
        except Exception as e:
            logger.debug(f"Token validation failed: {e}")
            return False

    async def get_auth_headers(self) -> Dict[str, str]:
        """
        Get authentication headers for API requests.

        Returns:
            Dictionary with Authorization header or empty dict
        """
        token = await self.get_valid_token()
        if token:
            return {"Authorization": f"Bearer {token}"}
        return {}

    def logout(self):
        """Clear authentication and logout."""
        try:
            self.supabase.auth.sign_out()
            self._clear_cached_session()
            self.cached_token = None
            self.token_expiry = None
            logger.info("✓ Logged out successfully")
        except Exception as e:
            logger.error(f"Logout failed: {e}")

    def get_user_info(self) -> Optional[Dict[str, Any]]:
        """
        Get current user information.

        Returns:
            User info dict or None
        """
        try:
            response = self.supabase.auth.get_user()
            if response and response.user:
                return {
                    "id": response.user.id,
                    "email": response.user.email,
                    "provider": response.user.app_metadata.get("provider") if response.user.app_metadata else None
                }
        except Exception as e:
            logger.warning(f"Failed to get user info: {e}")
        return None
