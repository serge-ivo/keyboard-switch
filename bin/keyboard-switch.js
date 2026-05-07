#!/usr/bin/env node

const { spawnSync } = require("node:child_process");
const { dirname, resolve } = require("node:path");

const packageRoot = resolve(dirname(__filename), "..");
const target = process.argv[2] ?? "help";
const supportedTargets = new Set(["build", "app", "install", "uninstall", "test", "clean"]);

if (process.platform !== "darwin") {
  console.error("keyboard-switch only supports macOS.");
  process.exit(1);
}

if (!supportedTargets.has(target)) {
  console.log("Usage: keyboard-switch <build|app|install|uninstall|test|clean>");
  process.exit(target === "help" ? 0 : 1);
}

const result = spawnSync("make", [target], {
  cwd: packageRoot,
  stdio: "inherit",
});

if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}

process.exit(result.status ?? 1);
