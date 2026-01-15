# PersonioTimer

A minimal macOS menubar app for starting and stopping attendance tracking in Personio.

## Features

- Lives in your menubar (no dock icon)
- One-click Start/Stop attendance tracking
- Optional live timer display
- Today's total tracked time
- Automatic state recovery after restart
- Midnight boundary handling (auto-stops to prevent cross-day entries)
- Secure credential storage in macOS Keychain

## Requirements

- macOS 13.0 (Ventura) or later
- Personio account with API access
- API credentials (Client ID & Client Secret)
- Your Personio Employee ID

## Installation

### Via Homebrew (Recommended)

```bash
# Add the tap (replace with actual tap name)
brew tap yourusername/tap

# Install
brew install --cask personio-timer
```

### Manual Installation

1. Download the latest release from [Releases](https://github.com/yourusername/personio-timer/releases)
2. Unzip and drag `PersonioTimer.app` to `/Applications`
3. Launch from Applications or Spotlight

## Setup

1. Launch PersonioTimer
2. Click the clock icon in the menubar
3. Select **Preferences...**
4. Enter your credentials:
   - **Client ID**: From Personio API settings
   - **Client Secret**: From Personio API settings
   - **Employee ID**: Your numeric employee ID
5. Click **Validate Credentials** to test
6. Click **Save**

### Getting API Credentials

1. Log into Personio
papi-b5d5f2de-0ba9-4541-8e0b-0f15ed3af793
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
┌─────────────────────┐
│ ⏱ Start / Stop      │  ← Primary action
├─────────────────────┤
│ Today: 4h 32m       │  ← Total tracked today
├─────────────────────┤
│ Sync Now            │
│ Open Personio       │
├─────────────────────┤
│ Preferences...      │
│ Quit PersonioTimer  │
└─────────────────────┘
```

## Midnight Handling

Personio attendance entries cannot span multiple days. PersonioTimer handles this automatically:

1. If tracking is active at 23:59, the current entry is stopped
2. If **Auto-restart after midnight** is enabled in Preferences, a new entry starts at 00:00

## Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/personio-timer.git
cd personio-timer/PersonioTimer

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
│   │   ├── AttendanceService.swift       # Business logic
│   │   └── MidnightScheduler.swift       # Day boundary handling
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
- Open Preferences and configure credentials and Employee ID

### Timer doesn't resume after restart
- Check if the previous entry was manually closed in Personio
- Verify network connectivity

### App doesn't appear in menubar
- Check System Settings > Control Center > Menu Bar Only
- Try quitting and relaunching the app

## License

MIT License - see LICENSE file for details.

---

## Manual Test Plan

### Prerequisites
- [ ] Have Personio API credentials ready
- [ ] Know your Employee ID
- [ ] Have access to Personio web interface for verification

### Test Cases

#### TC1: Initial Setup
1. [ ] Launch app - should appear in menubar with clock icon
2. [ ] Click icon - Start should be disabled (not configured)
3. [ ] Open Preferences
4. [ ] Enter valid Client ID and Secret
5. [ ] Click Validate - should show green checkmark
6. [ ] Enter Employee ID
7. [ ] Save and close

**Expected**: Start button becomes enabled

#### TC2: Start Tracking
1. [ ] Click Start
2. [ ] Wait for menu to update

**Expected**:
- Menu shows "Stop" instead of "Start"
- Menubar icon fills in (clock.fill)
- Timer appears in menubar (if enabled)
- Personio web shows new attendance entry

#### TC3: Stop Tracking
1. [ ] With tracking active, click Stop
2. [ ] Check Personio web

**Expected**:
- Menu shows "Start"
- Timer disappears
- Personio entry has end time set
- "Today: Xh Ym" updates

#### TC4: State Recovery
1. [ ] Start tracking
2. [ ] Quit app (Cmd+Q, confirm "Quit Anyway")
3. [ ] Relaunch app

**Expected**:
- App resumes tracking
- Timer continues from original start time
- No duplicate entry in Personio

#### TC5: Overlap Prevention
1. [ ] Start tracking in app
2. [ ] In Personio web, manually create another attendance entry for today
3. [ ] Stop and try to Start again in app

**Expected**: Error message about overlap (or graceful handling)

#### TC6: Quit with Active Tracking
1. [ ] Start tracking
2. [ ] Click Quit PersonioTimer

**Expected**: Dialog offers "Stop and Quit", "Quit Anyway", "Cancel"

#### TC7: Invalid Credentials
1. [ ] In Preferences, enter wrong Client Secret
2. [ ] Click Validate

**Expected**: Red X with "Invalid" message

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

**Expected**: Error message, state preserved for retry

#### EC2: Midnight Boundary (Manual Test)
1. [ ] Set system time to 23:58
2. [ ] Start tracking
3. [ ] Wait past midnight

**Expected**: Entry auto-stops at 23:59, optionally restarts at 00:00

### Sign-off

- [ ] All TC pass
- [ ] No credentials in logs (check Console.app)
- [ ] App uses < 50MB memory
- [ ] No CPU usage when idle
