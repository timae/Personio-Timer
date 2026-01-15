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

### Via Homebrew (Not yet supported)

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

