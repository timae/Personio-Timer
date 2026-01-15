# PersonioTimer

A minimal macOS menubar app for starting and stopping attendance tracking in Personio.

## Features

- Lives in your menubar (no dock icon)
- One-click Start/Stop attendance tracking
- Optional live timer display in menubar
- Today's total tracked time
- Status indicator showing configuration and connection state
- Automatic state recovery after restart
- Auto-opens setup on first launch
- Connection test to validate API credentials
- Secure credential storage in macOS Keychain

## Requirements

- macOS 13.0 (Ventura) or later
- Personio account with API access
- API credentials (Client ID & Client Secret)
- Your Personio Employee ID

## Installation

### Via Homebrew (Recommended)

```bash
# Add the tap
brew tap timae/tap

# Install
brew install --cask personio-timer
```

### Manual Installation

1. Download the latest release from [Releases](https://github.com/timae/Personio-Timer/releases)
2. Unzip and drag `PersonioTimer.app` to `/Applications`
3. Launch from Applications or Spotlight

## Setup

1. Launch PersonioTimer - Preferences window opens automatically on first launch
2. Enter your credentials:
   - **Client ID**: From Personio API settings
   - **Client Secret**: From Personio API settings
   - **Employee ID**: Your numeric employee ID
3. Click **Test Connection** to verify everything works
4. Click **Save**

### Getting API Credentials

1. Log into Personio
2. Go to **Settings** > **Integrations** > **API credentials**
3. Create new credentials with attendance read/write permissions
4. Copy the Client ID and Client Secret

### Finding Your Employee ID

Your Employee ID is visible in the URL when viewing your profile in Personio:
```
https://yourcompany.personio.de/staff/employees/12345
                                              ^^^^^
                                              Employee ID
```

## Usage

| Action | How |
|--------|-----|
| Start tracking | Click menubar icon > **Start** |
| Stop tracking | Click menubar icon > **Stop** |
| View today's total | Click menubar icon (shown in menu) |
| Sync totals | Click menubar icon > **Sync Now** |
| Open Personio | Click menubar icon > **Open Personio** |

## Menu Items

```
┌─────────────────────────┐
│ Status: Ready (ID: 123) │  ← Connection/config status
├─────────────────────────┤
│ Start / Stop            │  ← Primary action
│ Today: 4h 32m           │  ← Total tracked today
├─────────────────────────┤
│ Sync Now                │
│ Open Personio           │
├─────────────────────────┤
│ Preferences...          │
│ Quit PersonioTimer      │
└─────────────────────────┘
```

### Status Indicator

The status line shows:
- **Status: No API credentials** - Credentials not configured
- **Status: No Employee ID** - Employee ID not set
- **Status: Ready (ID: xxx)** - Configured and ready to track
- **Status: Tracking (ID: xxx)** - Currently tracking time
- **Status: Loading...** - API call in progress
- **Error: [message]** - Last operation failed

## Building from Source

```bash
# Clone the repository
git clone https://github.com/timae/Personio-Timer.git
cd Personio-Timer/PersonioTimer

# Build with Xcode
xcodebuild -project PersonioTimer.xcodeproj \
           -scheme PersonioTimer \
           -configuration Release \
           build

# Or open in Xcode
open PersonioTimer.xcodeproj
```

## Project Structure

```
PersonioTimer/
├── PersonioTimer/
│   ├── App/
│   │   ├── main.swift                    # Entry point
│   │   ├── AppDelegate.swift             # App lifecycle
│   │   ├── StatusBarController.swift     # Menubar UI
│   │   └── PreferencesWindowController.swift  # Settings window
│   ├── Core/
│   │   ├── PersonioAPIClient.swift       # HTTP client
│   │   ├── PersonioModels.swift          # API models
│   │   ├── TokenCache.swift              # Token storage
│   │   └── AttendanceService.swift       # Business logic
│   ├── Storage/
│   │   ├── KeychainStore.swift           # Secure credentials
│   │   └── LocalStateStore.swift         # App state
│   ├── Utilities/
│   │   └── TimeUtils.swift               # Time formatting
│   └── Resources/
│       └── Info.plist
├── Packaging/
│   ├── personio-timer.rb                 # Homebrew cask
│   ├── entitlements.plist
│   └── release-notes.md
└── README.md
```

## Security

- API credentials are stored in macOS Keychain
- Credentials are never logged or exposed
- Authentication tokens are kept in memory only
- Network requests use HTTPS

## Troubleshooting

### "Invalid credentials" error
- Verify Client ID and Secret in Personio
- Ensure the API credentials have attendance permissions
- Try generating new credentials

### Start button is disabled
- Check the Status line in the menu for details
- Open Preferences and configure credentials and Employee ID
- Use "Test Connection" to verify your setup

### Timer doesn't resume after restart
- Check if the previous entry was manually closed in Personio
- Verify network connectivity

### App doesn't appear in menubar
- Check System Settings > Control Center > Menu Bar Only
- Try quitting and relaunching the app

### Repeated Keychain password prompts (during development)
- This happens because each rebuild changes the app's code signature
- Click "Always Allow" when prompted
- For distribution builds with stable signing, this only happens once

## License

MIT License - see LICENSE file for details.

---

## Manual Test Plan

### Prerequisites
- [ ] Have Personio API credentials ready
- [ ] Know your Employee ID
- [ ] Have access to Personio web interface for verification

### Test Cases

#### TC1: Initial Setup (First Launch)
1. [ ] Launch app for the first time
2. [ ] Preferences window should open automatically
3. [ ] Enter valid Client ID, Secret, and Employee ID
4. [ ] Click "Test Connection"

**Expected**: Green checkmark with "Connected! Found X attendance(s) today"

#### TC2: Save and Ready State
1. [ ] After successful connection test, click Save
2. [ ] Check the menu

**Expected**:
- Status shows "Status: Ready (ID: xxx)"
- Start button is enabled

#### TC3: Start Tracking
1. [ ] Click Start
2. [ ] Wait for menu to update

**Expected**:
- Status shows "Status: Tracking (ID: xxx)"
- Menu shows "Stop" instead of "Start"
- Menubar icon fills in (clock.fill)
- Timer appears in menubar (if enabled in preferences)
- Personio web shows new attendance entry (open, no end time)

#### TC4: Stop Tracking
1. [ ] With tracking active, click Stop
2. [ ] Check Personio web

**Expected**:
- Status shows "Status: Ready (ID: xxx)"
- Menu shows "Start"
- Timer disappears from menubar
- Personio entry now has end time set
- "Today: Xh Ym" updates

#### TC5: State Recovery
1. [ ] Start tracking
2. [ ] Quit app (Cmd+Q, confirm "Quit Anyway")
3. [ ] Relaunch app

**Expected**:
- App resumes tracking
- Timer continues from original start time
- No duplicate entry in Personio

#### TC6: Quit with Active Tracking
1. [ ] Start tracking
2. [ ] Click Quit PersonioTimer

**Expected**: Dialog offers "Stop and Quit", "Quit Anyway", "Cancel"

#### TC7: Invalid Credentials Test
1. [ ] In Preferences, enter wrong Client Secret
2. [ ] Click "Test Connection"

**Expected**: Red X with error message

#### TC8: Sync Today's Total
1. [ ] Have some completed entries in Personio
2. [ ] Click Sync Now

**Expected**: Today total updates to match Personio

#### TC9: Preferences Persistence
1. [ ] Configure preferences
2. [ ] Quit app
3. [ ] Relaunch
4. [ ] Open Preferences

**Expected**: All values are preserved

#### TC10: Open Personio Link
1. [ ] Click "Open Personio"

**Expected**: Browser opens to Personio dashboard

### Edge Cases

#### EC1: Network Disconnection
1. [ ] Start tracking
2. [ ] Disconnect from network
3. [ ] Try to Stop

**Expected**: Error message shown in Status line, state preserved for retry

#### EC2: Overlap Prevention
1. [ ] Start tracking in app
2. [ ] In Personio web, manually create another attendance entry for today
3. [ ] Stop and try to Start again in app

**Expected**: Error message about overlap (or graceful handling)

### Sign-off

- [ ] All TC pass
- [ ] No credentials in logs (check Console.app, filter by "PersonioTimer")
- [ ] App uses < 50MB memory
- [ ] No CPU usage when idle
