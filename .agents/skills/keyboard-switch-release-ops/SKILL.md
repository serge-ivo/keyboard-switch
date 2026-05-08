---
name: keyboard-switch-release-ops
description: Use when working in the keyboard-switch repo on menu bar visibility regressions, Swift tests, npm packaging, or GitHub Actions release automation. Covers the fixed status-dot behavior, LaunchAgent rules, local install/test commands, and tag-driven npm plus GitHub release publishing.
---

# Keyboard Switch Release Ops

## Use this skill for

- changes in `keyboard-switch` that affect the menu bar dot, launch behavior, packaging, tests, or release automation
- preparing a release or fixing GitHub Actions / npm publishing in this repo
- restoring context after a new session so the release workflow does not need to be rediscovered

## Core assumptions

- The app is a native macOS Swift app. It is not built with npm.
- npm is only a wrapper around the native build/install flow.
- Publishing should stay tag-driven, not push-driven.

## Key files

- App entry: `Sources/KeyboardMonitor/main.swift`
- Testable presentation rules: `Sources/KeyboardSwitchCore/StatusDotPresentation.swift`
- LaunchAgent contract: `Sources/KeyboardSwitchCore/LaunchAgentDefinition.swift`
- Tests: `Tests/KeyboardSwitchCoreTests/`
- Native install flow: `Makefile`
- npm wrapper: `package.json`, `bin/keyboard-switch.js`
- GitHub Actions release flow: `.github/workflows/publish.yml`
- LaunchAgent plist: `com.serge.keyboardmonitor.plist`

## Non-negotiable behavior

- The visible status bar indicator must remain a single attributed dot glyph with explicit colors.
- Do not rely on `contentTintColor` to color plain text titles.
- The disconnected state is white; connected is green.
- The status item stays fixed-width so it remains visually stable.
- The LaunchAgent must open `/Applications/KeyboardMonitor.app` through `/usr/bin/open -a`, not the inner Mach-O path.

## Validation steps

1. Run `make test`.
2. If app behavior changed, run `make clean install`.
3. Verify the process if needed with `pgrep -fl KeyboardMonitor`.
4. Verify the LaunchAgent if needed with `launchctl list | rg "com\\.serge\\.keyboardmonitor"`.

## Release workflow

1. Ensure `make test` passes locally.
2. Commit and push the release changes.
3. Create and push a tag such as `v0.1.0`.
4. GitHub Actions will:
   - run `make test`
   - prepare the npm package name from `NPM_PACKAGE_NAME` or `npm whoami`
   - publish to npm using `NPM_TOKEN`
   - build `KeyboardMonitor.app`
   - attach `KeyboardMonitor.zip` to the GitHub release

## GitHub configuration

- Required secret: `NPM_TOKEN`
- Optional repo variable: `NPM_PACKAGE_NAME`
- Optional repo variable: `NPM_PACKAGE_SCOPE_USER`

If `NPM_PACKAGE_NAME` is unset, publishing defaults to `@<npm-username>/keyboard-switch`.

## Common failure modes

- Dot not visible:
  - check for accidental reintroduction of plain `title = "●"` plus `contentTintColor`
  - prefer the attributed-title path in `Sources/KeyboardMonitor/main.swift`
- App launches but no menu bar item:
  - verify the app process is actually running
  - verify the LaunchAgent still uses `/usr/bin/open -a /Applications/KeyboardMonitor.app`
- npm publish `404`:
  - the token account likely does not own the package scope
  - set `NPM_PACKAGE_NAME` explicitly or use the correct npm account token
