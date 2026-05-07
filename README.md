# Keyboard Switch

A tiny macOS menu bar utility that shows whether your Bluetooth keyboard is currently connected to this machine.

If you share a single Bluetooth keyboard across multiple Macs (e.g. a Logitech K380 or similar multi-device keyboard), it can be hard to tell which machine it's currently talking to. Keyboard Switch puts a colored dot in your menu bar:

- **Green** — keyboard is connected to this Mac
- **White** — keyboard is connected elsewhere (or off)

The dot updates as soon as macOS reports the keyboard connected or disconnected.

## Requirements

- macOS 12+
- Xcode Command Line Tools (`xcode-select --install`)

## Quick start (new machine)

1. Install Xcode Command Line Tools (if not already installed):
   ```bash
   xcode-select --install
   ```

2. Clone and find your keyboard's Bluetooth name:
   ```bash
   git clone https://github.com/serge-ivo/keyboard-switch.git
   cd keyboard-switch
   system_profiler SPBluetoothDataType | grep -B1 "Minor Type: Keyboard"
   ```

3. Edit the device name in `Sources/KeyboardMonitor/main.swift` to match your keyboard:
   ```swift
   let deviceName = "MK550KB"  // change to your keyboard's Bluetooth name
   ```

4. Run tests, then build, install, and enable auto-start:
   ```bash
   make test
   make install
   ```

That's it. The app is now running and will start automatically on login.

## Install (alternative methods)

### From a release

Download `KeyboardMonitor.zip` from the [Releases](https://github.com/serge-ivo/keyboard-switch/releases) page, unzip, and move `KeyboardMonitor.app` to `/Applications`. Double-click to launch. Note: release builds won't auto-start on login — you'll need to add the app manually in **System Settings → General → Login Items**.

## Configuration

To change the monitored keyboard later, edit the `deviceName` variable in `Sources/KeyboardMonitor/main.swift` and rebuild:

```bash
make test
make install
```

## Testing

Unit tests cover the fragile parts that broke during the status bar iterations:

- the status item should render as an attributed dot, not a plain text title tinted with `contentTintColor`
- the dot presentation should stay fixed-width and preserve the green/white connected state semantics
- the LaunchAgent should start the `.app` through `/usr/bin/open -a /Applications/KeyboardMonitor.app`, not the inner Mach-O directly

Run them with:

```bash
make test
```

## npm package

This repo now includes a small npm wrapper so you can drive the native macOS app through npm without changing the actual Swift build:

```bash
npm install
npm test
npx @serge-ivo/keyboard-switch install
```

The npm package is macOS-only and delegates to `make build`, `make test`, `make install`, and `make uninstall`.

## CI publishing

GitHub Actions now supports two publish modes:

- every push to `main` runs tests and publishes a unique npm `canary` build
- every pushed tag matching `v*` runs tests, publishes the stable npm package, builds the app bundle, and creates a GitHub release zip

Required GitHub secret:

- `NPM_TOKEN`: npm access token for the personal account that should own the package

Optional GitHub variables or secrets:

- `NPM_PACKAGE_NAME`: explicit package name to publish, for example `@your-npm-user/keyboard-switch`
- `NPM_PACKAGE_SCOPE_USER`: override for the npm username used to derive `@username/keyboard-switch`

If `NPM_PACKAGE_NAME` is not set, the workflow runs `npm whoami` with `NPM_TOKEN` and publishes as `@<npm-username>/keyboard-switch`.

## Start at login

`make install` automatically installs a LaunchAgent that starts the app on login — no manual setup needed.

To manage it manually:

```bash
# Stop auto-starting
launchctl unload ~/Library/LaunchAgents/com.serge.keyboardmonitor.plist

# Re-enable auto-starting
launchctl load ~/Library/LaunchAgents/com.serge.keyboardmonitor.plist
```

## Menu bar on all displays

If the dot only shows on one screen, enable **System Settings → Desktop & Dock → Mission Control → "Displays have separate Spaces"** (requires log out/in).

## Uninstall

```bash
make uninstall
```

## How it works

The app uses native `IOBluetooth` connect/disconnect notifications for the target device and checks its current connection state at launch. It runs as a menu bar-only app with no Dock icon. Click the dot to quit.

## Learnings

- `contentTintColor` is for images; it is not a reliable way to color a plain text menu bar title. The visible dot now goes through an attributed title with explicit colors.
- The app is easiest to keep visible when the status item stays fixed-width and always renders a single dot glyph.
- The LaunchAgent must open the app bundle with `/usr/bin/open -a /Applications/KeyboardMonitor.app`. Pointing the agent at the inner executable caused unreliable launches.
- `swift test` now guards the presentation and LaunchAgent assumptions that regressed during debugging.
