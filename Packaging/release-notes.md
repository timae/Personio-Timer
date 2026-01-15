# Release Notes

## Version 1.0.0

Initial release of PersonioTimer.

### Features

- **Menubar Integration**: Lives in your macOS menubar with no dock icon
- **Start/Stop Tracking**: One-click attendance tracking via Personio API
- **Timer Display**: Optional live timer showing current session duration
- **Today's Total**: View total tracked time for today
- **State Recovery**: Automatically resumes tracking after app restart
- **Midnight Handling**: Auto-stops at midnight to prevent cross-day entries
- **Secure Storage**: API credentials stored in macOS Keychain

### Requirements

- macOS 13.0 (Ventura) or later
- Personio account with API access
- API credentials (Client ID & Secret)
- Your Personio Employee ID

### Known Limitations

- Single-user only (tracks for one employee ID)
- Requires manual employee ID entry (no automatic lookup)
- Break time must be entered manually in Personio web interface

### Building from Source

```bash
cd PersonioTimer
xcodebuild -project PersonioTimer.xcodeproj -scheme PersonioTimer -configuration Release build
```

### Creating a Release

1. Archive in Xcode: Product > Archive
2. Export with "Developer ID" signing (or unsigned for testing)
3. Create zip: `zip -r PersonioTimer-1.0.0.zip PersonioTimer.app`
4. Calculate SHA256: `shasum -a 256 PersonioTimer-1.0.0.zip`
5. Upload to GitHub Releases
6. Update cask formula with new SHA256
