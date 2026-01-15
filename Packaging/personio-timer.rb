# Homebrew Cask for PersonioTimer
#
# Installation:
#   1. Host the .zip on a public URL (GitHub Releases recommended)
#   2. Update the url and sha256 below
#   3. Submit to homebrew-cask or use a personal tap:
#      brew tap yourusername/tap
#      brew install --cask personio-timer
#
# Building the release:
#   1. Archive in Xcode: Product > Archive
#   2. Export as "Developer ID" signed app (or unsigned for local use)
#   3. Create zip: cd /path/to/export && zip -r PersonioTimer-1.0.0.zip PersonioTimer.app
#   4. Calculate SHA: shasum -a 256 PersonioTimer-1.0.0.zip

cask "personio-timer" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256_HASH"

  url "https://github.com/YOURUSERNAME/personio-timer/releases/download/v#{version}/PersonioTimer-#{version}.zip"
  name "PersonioTimer"
  desc "Menubar app for Personio attendance tracking"
  homepage "https://github.com/YOURUSERNAME/personio-timer"

  # Requires macOS 13.0 (Ventura) or later
  depends_on macos: ">= :ventura"

  app "PersonioTimer.app"

  zap trash: [
    "~/Library/Preferences/com.example.PersonioTimer.plist",
    "~/Library/Application Support/PersonioTimer",
  ]

  caveats <<~EOS
    PersonioTimer requires API credentials from your Personio account.

    To configure:
    1. Launch PersonioTimer from your Applications folder
    2. Click the clock icon in the menubar
    3. Select "Preferences..."
    4. Enter your Client ID, Client Secret, and Employee ID

    Get API credentials from Personio:
    Settings > Integrations > API credentials
  EOS
end
