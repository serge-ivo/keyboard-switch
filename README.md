# Keyboard Switch

A tiny macOS menu bar utility that shows whether your Bluetooth keyboard is currently connected to this machine.

If you share a single Bluetooth keyboard across multiple Macs (e.g. a Logitech K380 or similar multi-device keyboard), it can be hard to tell which machine it's currently talking to. Keyboard Switch puts a colored dot in your menu bar:

- **Green** — keyboard is connected to this Mac
- **Gray** — keyboard is connected elsewhere (or off)

The dot updates every 3 seconds.

## Requirements

- macOS 12+
- Xcode Command Line Tools (`xcode-select --install`)

## Install

### From source

```bash
git clone https://github.com/serge-ivo/keyboard-switch.git
cd keyboard-switch
make install
```

This builds the app, copies it to `/Applications`, and launches it.

### From a release

Download `KeyboardMonitor.zip` from the [Releases](https://github.com/serge-ivo/keyboard-switch/releases) page, unzip, and move `KeyboardMonitor.app` to `/Applications`. Double-click to launch.

## Configuration

By default the app monitors a device named `MK550KB`. To monitor a different keyboard, edit the `deviceName` variable in `KeyboardMonitor.swift`:

```swift
let deviceName = "MK550KB"  // change to your keyboard's Bluetooth name
```

To find your keyboard's Bluetooth name, run:

```bash
system_profiler SPBluetoothDataType | grep -B1 "Minor Type: Keyboard"
```

Then rebuild and reinstall:

```bash
make install
```

## Start at login

After installing, go to **System Settings → General → Login Items** and add **KeyboardMonitor**.

## Menu bar on all displays

If the dot only shows on one screen, enable **System Settings → Desktop & Dock → Mission Control → "Displays have separate Spaces"** (requires log out/in).

## Uninstall

```bash
make uninstall
```

## How it works

The app polls `system_profiler SPBluetoothDataType` every 3 seconds and checks whether the target device appears under the "Connected" section. It runs as a menu bar-only app with no Dock icon. Click the dot to quit.
