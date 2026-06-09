#!/usr/bin/env node
// Render aider-desk-extensions.yaml into two CSV artifacts consumed by
// shiki.Dockerfile (install list) and entrypoint.sh (disabled list).
//
// Usage:
//   node render-aiderdesk-extensions.js <input.yaml> <install.csv> <disabled.csv>
//
// install.csv  = unique(enabled ∪ disabled), comma-joined, single line.
// disabled.csv = disabled list, comma-joined, single line.
//
// Run inside the AiderDesk image at build time; relies on the bundled
// `yaml` package at /app/node_modules/yaml — no extra deps.

'use strict';

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
if (args.length !== 3) {
  console.error(
    'usage: render-aiderdesk-extensions.js <input.yaml> <install.csv> <disabled.csv>',
  );
  process.exit(2);
}

const inputPath = args[0];
const installPath = args[1];
const disabledPath = args[2];

// Prefer the AiderDesk-bundled yaml package; fall back to a sibling
// node_modules lookup for off-image testing.
let YAML;
try {
  YAML = require('/app/node_modules/yaml');
} catch (_) {
  YAML = require('yaml');
}

const raw = fs.readFileSync(inputPath, 'utf8');
const doc = YAML.parse(raw) || {};

const asList = (value) => (Array.isArray(value) ? value : []);
const enabled = asList(doc.enabled).map(String).map((s) => s.trim()).filter(Boolean);
const disabled = asList(doc.disabled).map(String).map((s) => s.trim()).filter(Boolean);

const install = Array.from(new Set([...enabled, ...disabled]));

const writeCsv = (target, ids) => {
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, ids.join(',') + '\n');
};

writeCsv(installPath, install);
writeCsv(disabledPath, disabled);

console.log(
  `rendered ${install.length} install id(s), ${disabled.length} disabled id(s) from ${inputPath}`,
);
