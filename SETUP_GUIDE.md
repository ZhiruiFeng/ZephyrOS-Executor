# ZephyrOS Executor Setup Guide

Complete guide to set up and run the ZephyrOS Executor macOS app with Google OAuth authentication.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Google OAuth Setup](#google-oauth-setup)
4. [Xcode Configuration](#xcode-configuration)
5. [Environment Variables](#environment-variables)
6. [Building and Running](#building-and-running)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- **macOS 14.0+** (for development and running)
- **Xcode 15.0+**
- **Google Cloud Console access** (to create OAuth client)
- **ZMemory API access** (get credentials from admin)

---

## Quick Start

```bash
# 1. Clone and navigate to project
cd "ZephyrOS Executor"

# 2. Copy environment template
cp .env.example .env

# 3. Edit .env with your credentials (see Environment Variables section)

# 4. Open in Xcode
open "ZephyrOS Executor.xcodeproj"

# 5. Configure (see Xcode Configuration section)

# 6. Build and Run (Cmd + R)
```

---

## Google OAuth Setup

### Step 1: Create iOS OAuth Client

1. Go to [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)

2. Click **+ CREATE CREDENTIALS** → **OAuth client ID**

3. Configure:
   - **Application type**: iOS
   - **Name**: `ZephyrOS Executor (macOS)`
   - **Bundle ID**: `Zephyr.ZephyrOS-Executor`

4. Click **Create**

5. **Copy the Client ID** (it looks like: `123456789-abc123.apps.googleusercontent.com`)

   ⚠️ **Note**: iOS/macOS OAuth clients don't have a client secret - this is normal!

### Step 2: Configure OAuth Consent Screen

1. Go to **OAuth consent screen**
2. Add your email as a **Test user** (if app is in testing mode)
3. Ensure scopes include: `openid`, `email`, `profile`

---

## Xcode Configuration

### 0. Create a Personal (Unshared) Scheme

To keep secrets out of source control, duplicate the shared scheme and store
your credentials in a personal copy:

1. In Xcode, choose **Product → Scheme → Manage Schemes…**
2. Select `ZephyrOS Executor` and click **Duplicate**
3. Name it something like `ZephyrOS Executor (YourName)`
4. **Uncheck** the **Shared** checkbox for the new scheme
5. Click **Close**

Xcode saves unshared schemes under `xcuserdata`, which is already ignored by Git.
Use this personal scheme whenever you edit environment variables.

### 1. Configure URL Scheme

The app needs to handle OAuth callbacks via a custom URL scheme.

**Steps:**

1. In Xcode, select **ZephyrOS Executor** target
2. Click **Info** tab
3. Expand **URL Types** section
4. Click **+** to add a new URL Type
5. Configure:
   - **Identifier**: `Zephyr.ZephyrOS-Executor`
   - **URL Schemes**: `com.googleusercontent.apps.{YOUR_CLIENT_ID}`
     - Replace `{YOUR_CLIENT_ID}` with the prefix from your Client ID
     - Example: `com.googleusercontent.apps.123456789-abc123`
   - **Role**: Editor
6. Save (Cmd + S)

**Verify it works:**
```bash
# Replace with your actual URL scheme
open "com.googleusercontent.apps.123456789-abc123://test"
```
Your app should launch!

### 2. Set Environment Variables in Xcode

Set environment variables on the personal scheme you just created:

**Steps:**

1. Click the scheme dropdown → Select your personal scheme → **"Edit Scheme..."**
2. Left sidebar: **Run** → Top tabs: **Arguments**
3. Find **Environment Variables** section
4. Click **+** to add each variable:

| Name | Value | Example |
|------|-------|---------|
| `GOOGLE_CLIENT_ID` | Your iOS Client ID | `123456789-abc123.apps.googleusercontent.com` |
| `GOOGLE_REDIRECT_URI` | Redirect URI | `com.googleusercontent.apps.123456789-abc123:/oauth/callback` |
| `ZMEMORY_API_URL` | ZMemory API endpoint | `https://zmemory.vercel.app` |
| `ZMEMORY_API_KEY` | ZMemory API key | Get from admin |
| `ANTHROPIC_API_KEY` | Claude API key | Get from Anthropic |
| `SUPABASE_URL` | Supabase URL (optional) | `https://yourproject.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anon key (optional) | Get from Supabase |

5. Click **Close**

---

## Environment Variables

### Option 1: Personal Xcode Scheme (Recommended)

See [Xcode Configuration](#2-set-environment-variables-in-xcode) above.

✅ **Pros**: Most reliable, immediate, no file searching, stays local
❌ **Cons**: Need to set for each developer

### Option 2: .env File

The app will try to load `.env` from the project root.

**Steps:**

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your credentials:
   ```bash
   # Google OAuth Configuration
   GOOGLE_CLIENT_ID=123456789-abc123.apps.googleusercontent.com
   GOOGLE_REDIRECT_URI=com.googleusercontent.apps.123456789-abc123:/oauth/callback

   # ZMemory API Configuration
   ZMEMORY_API_URL=https://zmemory.vercel.app
   ZMEMORY_API_KEY=your_zmemory_api_key

   # Anthropic Claude API Configuration
   ANTHROPIC_API_KEY=your_anthropic_api_key

   # Supabase Configuration (optional)
   SUPABASE_URL=https://yourproject.supabase.co
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

3. Save the file

⚠️ **Note**: The `.env` file is in `.gitignore` and won't be committed.

---

## Building and Running

### Clean and Build

```bash
# In Xcode:
Product → Clean Build Folder (Shift + Cmd + K)
Product → Build (Cmd + B)
Product → Run (Cmd + R)
```

### First Run

1. App launches and shows **Login** screen
2. Click **"Sign in with Google"**
3. Browser opens with Google OAuth consent
4. Authorize the app
5. Redirects back to app
6. Main interface appears with:
   - Dashboard
   - Tasks
   - Logs
   - Profile (your account info)
   - Settings

---

## Troubleshooting

### "Access blocked: Authorization Error"

**Cause**: Using wrong OAuth client type (web instead of iOS)

**Fix**: Create a new iOS OAuth client in Google Cloud Console (see [Google OAuth Setup](#google-oauth-setup))

---

### "redirect_uri_mismatch"

**Cause**: Redirect URI doesn't match Google Cloud Console configuration

**Fix**:
1. Check your URL scheme in Xcode matches the format: `com.googleusercontent.apps.{CLIENT_ID}`
2. Update `GOOGLE_REDIRECT_URI` environment variable to match
3. iOS clients auto-accept this format, no manual registration needed

---

### "Missing required parameter: client_id"

**Cause**: Environment variables not loading

**Fix**:
1. Verify environment variables are set in Xcode scheme (preferred method)
2. Check that Client ID is correct
3. Clean build and restart Xcode

---

### Network Error "Error Code: -1003"

**Cause**: App Sandbox blocking network access

**Fix**: Already fixed in `ZephyrOS_Executor.entitlements` with:
```xml
<key>com.apple.security.network.client</key>
<true/>
```

If still occurring, verify in Target → Signing & Capabilities → App Sandbox → Network: Outgoing Connections (Client) is checked.

---

### .env File Not Found

**Cause**: Xcode builds to a different location, file path searching fails

**Fix**: Use Xcode Scheme environment variables (recommended) or set absolute path

---

### URL Scheme Not Working

**Cause**: URL scheme not registered or incorrect format

**Fix**:
1. Verify URL scheme in Xcode Info tab
2. Test with Terminal: `open "your-url-scheme://test"`
3. Clean build and rebuild

---

## Additional Documentation

- **README.md** - Project overview and features
- **ARCHITECTURE.md** - Technical architecture details
- **CHANGELOG.md** - Recent updates and changes
- **.env.example** - Environment variable template

---

## Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Verify all configuration steps were completed
3. Check Xcode console for error messages
4. Review environment variable values in Xcode scheme

---

## Security Notes

- ✅ `.env` file is gitignored
- ✅ No credentials in source code
- ✅ OAuth tokens stored in UserDefaults (consider Keychain for production)
- ✅ All API calls use HTTPS
- ✅ App Sandbox enabled with minimal permissions

---

## Quick Reference

### Required Credentials

| Credential | Where to Get | Required |
|------------|--------------|----------|
| Google Client ID | Google Cloud Console → OAuth iOS client | ✅ Yes |
| ZMemory API URL | ZephyrOS Admin | ✅ Yes |
| ZMemory API Key | ZephyrOS Admin | ✅ Yes |
| Anthropic API Key | Anthropic Dashboard | ✅ Yes |
| Supabase URL | Supabase Project Settings | ⚠️ Optional |
| Supabase Anon Key | Supabase Project Settings | ⚠️ Optional |

### Key File Locations

```
ZephyrOS Executor/
├── .env                              (Your credentials - not in git)
├── .env.example                      (Template)
├── ZephyrOS Executor/
│   ├── ZephyrOS Executor/
│   │   ├── Config/
│   │   │   └── Environment.swift     (Loads env vars)
│   │   ├── Services/
│   │   │   └── GoogleAuthService.swift  (OAuth flow)
│   │   └── ZephyrOS_Executor.entitlements  (Permissions)
└── SETUP_GUIDE.md                    (This file)
```

---

**You're all set!** Run the app and sign in with Google to get started. 🚀
