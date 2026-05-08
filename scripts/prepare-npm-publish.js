#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const packagePath = path.resolve(__dirname, "..", "package.json");
const packageJson = JSON.parse(fs.readFileSync(packagePath, "utf8"));
const mode = process.argv[2] ?? "release";

const npmUsername = process.env.NPM_PACKAGE_SCOPE_USER || execFileSync("npm", ["whoami"], {
  encoding: "utf8",
}).trim();

const packageName = process.env.NPM_PACKAGE_NAME || `@${npmUsername}/keyboard-switch`;

packageJson.name = packageName;

if (mode === "release") {
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
