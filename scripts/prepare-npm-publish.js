#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const packagePath = path.resolve(__dirname, "..", "package.json");
const packageJson = JSON.parse(fs.readFileSync(packagePath, "utf8"));
const mode = process.argv[2] ?? "snapshot";

const npmUsername = process.env.NPM_PACKAGE_SCOPE_USER || execFileSync("npm", ["whoami"], {
  encoding: "utf8",
}).trim();

const packageName = process.env.NPM_PACKAGE_NAME || `@${npmUsername}/keyboard-switch`;

packageJson.name = packageName;

if (mode === "snapshot") {
  const runNumber = process.env.GITHUB_RUN_NUMBER || "0";
  const sha = (process.env.GITHUB_SHA || "dev").slice(0, 7);
  packageJson.version = `${packageJson.version}-canary.${runNumber}.${sha}`;
  packageJson.publishConfig = {
    ...(packageJson.publishConfig || {}),
    access: "public",
    tag: "canary",
  };
} else if (mode === "release") {
  packageJson.publishConfig = {
    ...(packageJson.publishConfig || {}),
    access: "public",
    tag: "latest",
  };
} else {
  console.error(`Unknown publish mode: ${mode}`);
  process.exit(1);
}

fs.writeFileSync(packagePath, `${JSON.stringify(packageJson, null, 2)}\n`);
console.log(`Prepared ${packageJson.name}@${packageJson.version} for ${mode} publish`);
