# Changelog

## Recent Updates

### ✅ Google OAuth Authentication (Completed)

**Features Added:**
- ✅ Google OAuth login with iOS client support
- ✅ Login view with Google Sign In button
- ✅ Session persistence (auto-login on app restart)
- ✅ OAuth token integration with ZMemory API
- ✅ User profile display with account information
- ✅ Sign out functionality

**Technical Changes:**
- Created `GoogleAuthService.swift` for OAuth flow handling
- Created `LoginView.swift` for authentication UI
- Created `ProfileView.swift` for user account display
- Updated `ZMemoryClient.swift` to use OAuth tokens
- Updated `ExecutorManager.swift` with authentication state
- Updated `ContentView.swift` to add Profile tab
- Added App Sandbox network permissions in entitlements
- Environment variable loader for `.env` file support

**Configuration:**
- Google OAuth uses iOS client type
- Redirect URI format: `com.googleusercontent.apps.{CLIENT_ID}:/oauth/callback`
- Environment variables can be set in `.env` or Xcode scheme
- No client secret needed for iOS/macOS apps

### 🧹 Code Cleanup (Completed)

**Removed:**
- ❌ All debugging print statements
- ❌ Verbose logging in Environment.swift
- ❌ Debug logs in GoogleAuthService.swift
- ❌ Token exchange error logging

**Security:**
- ✅ No hardcoded credentials in source code
- ✅ Credentials only in `.env` file (gitignored)
- ✅ Documentation uses placeholder values

### 📱 User Interface Updates

**New Views:**
- **Profile View**: Displays user information with avatar, name, email
  - User initials avatar with gradient background
  - Authentication status indicator
  - Sign out action with confirmation dialog

**Navigation:**
- Added "Profile" tab in sidebar navigation
- Icon: person.circle.fill
- Located between "Logs" and "Settings"

## File Structure

```
ZephyrOS Executor/
├── Config/
│   └── Environment.swift          (Cleaned up, no debug logs)
├── Services/
│   ├── GoogleAuthService.swift    (OAuth authentication)
│   ├── ZMemoryClient.swift        (Updated with OAuth support)
│   └── ExecutorManager.swift      (Authentication state)
├── Views/
│   ├── LoginView.swift            (NEW: Google Sign In)
│   ├── ProfileView.swift          (NEW: User profile display)
│   ├── ContentView.swift          (Updated: Profile tab added)
│   ├── DashboardView.swift
│   ├── TaskQueueView.swift
│   ├── LogsView.swift
│   └── SettingsView.swift
└── ZephyrOSExecutorApp.swift      (Updated: Login flow)
```

## Environment Setup

### Required Environment Variables

Set these in Xcode Scheme (recommended) or `.env` file:

```bash
# Google OAuth (iOS client)
GOOGLE_CLIENT_ID=your_ios_client_id.apps.googleusercontent.com
GOOGLE_REDIRECT_URI=com.googleusercontent.apps.{CLIENT_ID}:/oauth/callback

# ZMemory API
ZMEMORY_API_URL=https://zmemory.vercel.app
ZMEMORY_API_KEY=your_zmemory_api_key

# Claude API
ANTHROPIC_API_KEY=your_anthropic_api_key

# Supabase (optional)
SUPABASE_URL=https://your_project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### Xcode Configuration

**URL Scheme:**
- Add in Target → Info → URL Types
- Identifier: `Zephyr.ZephyrOS-Executor`
- URL Schemes: `com.googleusercontent.apps.{YOUR_CLIENT_ID}`

**Entitlements:**
- App Sandbox: Enabled
- Network Client: Enabled ✅
- Network Server: Enabled ✅

## Authentication Flow

1. **App Launch** → Check for saved session
2. **Not Authenticated** → Show LoginView
3. **Click "Sign in with Google"** → Open OAuth flow
4. **User Authorizes** → Redirect back to app
5. **Exchange Code** → Get access token
6. **Fetch User Info** → Get name and email
7. **Store Token** → Save in UserDefaults
8. **Set in ZMemoryClient** → Use for API calls
9. **Show Main App** → Display ContentView with Profile tab

## User Profile Features

**Display:**
- Avatar with user initials (gradient background)
- Full name
- Email address
- Authentication status (green dot + "Signed in")

**Actions:**
- Sign Out (with confirmation dialog)
- Stops executor and returns to login screen

## Documentation

- `OAUTH_SETUP.md` - Complete OAuth setup guide
- `OAUTH_FIX.md` - Troubleshooting guide
- `XCODE_URL_SCHEME_SETUP.md` - URL scheme configuration
- `SET_XCODE_ENV_VARS.md` - Environment variable setup
- `UPDATE_URL_SCHEME.md` - Redirect URI configuration

## Known Issues

- One warning about main actor isolation (non-critical, Swift 6 compatibility)
- `.env` file auto-loading works but Xcode scheme is more reliable

## Next Steps

Potential future enhancements:
- [ ] Use macOS Keychain for token storage (more secure than UserDefaults)
- [ ] Add token refresh logic for expired tokens
- [ ] Profile picture from Google account
- [ ] Account switching support
- [ ] Session timeout handling
