import { readFileSync, writeFileSync } from 'fs';
import { execSync } from 'child_process';

/**
 * MIGRATION RECORD — one-off rebrand script, kept for provenance.
 *
 * This file is the only place in the repository where the previous product
 * name still appears, and that is deliberate: it documents exactly which
 * identifiers were rewritten and in what order. Re-running it is a no-op.
 *
 * Do not treat it as application code.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Controlled rebrand migration: Kacung -> Lafly.
 *
 * Only git-tracked text files are touched. Build output, dependencies, git
 * history, and the signed app bundle are excluded on purpose — they are either
 * generated, binary, or must keep the old bytes until the project is rebuilt.
 *
 * Replacements are ordered longest-first so a compound identifier is never
 * partially rewritten (KacungAgentAppOptions must not become LaflyAppOptions).
 */

// Ordered: longest / most specific first.
const REPLACEMENTS = [
  ['KacungAgentAppOptions', 'LaflyAgentAppOptions'],
  ['KacungAgentApp', 'LaflyAgentApp'],
  ['KacungAgentRuntime', 'LaflyAgentRuntime'],
  ['KacungAgent', 'LaflyAgent'],
  ['KacungConfig', 'LaflyConfig'],
  ['KacungSandbox', 'LaflySandbox'],
  ['KacungApp', 'LaflyApp'],
  ['Kacung.app', 'Lafly.app'],
  ['kacung-monorepo', 'lafly-monorepo'],
  ['kacung-agent', 'lafly-agent'],
  ['kacung-screenshots', 'lafly-screenshots'],
  ['com.dynrbni.kacung', 'com.dynrbni.lafly'],
  ['kacung-step', 'lafly-step'],
  ['kacung-test', 'lafly-test'],
  ['kacung-mem', 'lafly-mem'],
  ['kacung-word', 'lafly-word'],
  ['kacung-tts', 'lafly-tts'],
  ['kacung-speech', 'lafly-speech'],
  ['@kacung/', '@lafly/'],
  ['KACUNG', 'LAFLY'],
  ['kacung.git', 'lafly.git'],
  ['kacung', 'lafly'],
  ['Kacung', 'Lafly'],
];

const files = execSync('git ls-files', { encoding: 'utf8' })
  .split('\n')
  .filter(Boolean)
  .filter((f) => !/\.app\//.test(f))
  .filter((f) => f !== 'pnpm-lock.yaml');

let changedFiles = 0;
const report = [];

for (const file of files) {
  let src;
  try {
    src = readFileSync(file, 'utf8');
  } catch {
    continue;
  }

  let out = src;
  const hits = [];

  for (const [from, to] of REPLACEMENTS) {
    if (!out.includes(from)) continue;
    const count = out.split(from).length - 1;
    out = out.split(from).join(to);
    hits.push(`${from} -> ${to} (${count})`);
  }

  if (out !== src) {
    writeFileSync(file, out);
    changedFiles++;
    report.push({ file, hits });
  }
}

for (const { file, hits } of report) {
  console.log(`\n${file}`);
  for (const h of hits) console.log(`    ${h}`);
}

console.log(`\n=== files changed: ${changedFiles} ===`);
