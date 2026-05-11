#!/usr/bin/env node

const { spawnSync } = require("node:child_process");
const { dirname, resolve } = require("node:path");

const packageRoot = resolve(dirname(__filename), "..");

if (process.platform !== "darwin") {
  process.exit(0);
}

if (process.env.CI === "true" || process.env.KEYBOARD_SWITCH_SKIP_INSTALL === "1") {
  process.exit(0);
}

const result = spawnSync("node", [resolve(packageRoot, "bin", "keyboard-switch.js"), "install"], {
  cwd: packageRoot,
  stdio: "inherit",
});

if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}

process.exit(result.status ?? 1);
