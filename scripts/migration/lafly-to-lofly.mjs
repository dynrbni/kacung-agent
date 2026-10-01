import { readFileSync, writeFileSync } from 'fs';
import { execSync } from 'child_process';

/**
 * MIGRATION RECORD — one-off rebrand script, kept for provenance.
 *
 * This file and `kacung-to-lafly.mjs` are the only places in the repository
 * where a superseded product name still appears, and that is deliberate: they
 * document exactly which identifiers were rewritten and in what order.
 * Re-running either is a no-op.
 *
 * Do not treat either as application code.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Controlled rebrand migration: Lafly -> Lofly.
 *
 * Only git-tracked text files are touched. Build output, dependencies, git
 * history, and the signed app bundle are excluded on purpose — they are either
 * generated, binary, or must keep the old bytes until the project is rebuilt.
 *
 * Replacements are ordered longest-first so a compound identifier is never
 * partially rewritten (LoflyAgentAppOptions must not become LoflyAppOptions).
 */

const SKIP = new Set([
  // This file, and the record it supersedes.
  'scripts/migration/lafly-to-lofly.mjs',
  'scripts/migration/kacung-to-lafly.mjs',
  // Rewritten by hand; it has to name the previous brand to detect it.
  'tests/rebrand-validation.test.ts',
]);

// Ordered: longest / most specific first.
const REPLACEMENTS = [
  ['LaflyAgentAppOptions', 'LoflyAgentAppOptions'],
  ['LaflyAgentApp', 'LoflyAgentApp'],
  ['LaflyAgentRuntime', 'LoflyAgentRuntime'],
  ['LaflyAgent', 'LoflyAgent'],
  ['LaflyConfig', 'LoflyConfig'],
  ['LaflySettings', 'LoflySettings'],
  ['LaflyTheme', 'LoflyTheme'],
  ['LaflySeparator', 'LoflySeparator'],
  ['LaflySectionHeader', 'LoflySectionHeader'],
  ['LaflyStatusPill', 'LoflyStatusPill'],
  ['LaflySoonBadge', 'LoflySoonBadge'],
  ['LaflySidebarSearchField', 'LoflySidebarSearchField'],
  ['LaflySidebarHeader', 'LoflySidebarHeader'],
  ['LaflyBanner', 'LoflyBanner'],
  ['LaflyApp', 'LoflyApp'],
  ['LaflySandbox', 'LoflySandbox'],
  ['Lafly.app', 'Lofly.app'],
  ['LaflyDesktopWindow', 'LoflyDesktopWindow'],
  ['LAFLY_TEST_ALLOW_LIVE', 'LOFLY_TEST_ALLOW_LIVE'],
  ['LAFLY_EXECUTION_MODE', 'LOFLY_EXECUTION_MODE'],
  ['LAFLY_SANDBOX_ROOT', 'LOFLY_SANDBOX_ROOT'],
  ['LAFLY_ENV', 'LOFLY_ENV'],
  ['lafly-monorepo', 'lofly-monorepo'],
  ['lafly-agent', 'lofly-agent'],
  ['lafly-screenshots', 'lofly-screenshots'],
  ['lafly-sandbox', 'lofly-sandbox'],
  ['lafly-desktop-test-', 'lofly-desktop-test-'],
  ['lafly-desktop-app-', 'lofly-desktop-app-'],
  ['lafly-step', 'lofly-step'],
  ['lafly-test', 'lofly-test'],
  ['lafly-mem', 'lofly-mem'],
  ['lafly-word', 'lofly-word'],
  ['lafly-tts', 'lofly-tts'],
  ['lafly-speech', 'lofly-speech'],
  ['lafly-screenshots', 'lofly-screenshots'],
  ['com.dynrbni.lafly', 'com.dynrbni.lofly'],
  ['.lafly', '.lofly'],
  ['@lafly/', '@lofly/'],
  ['lafly.git', 'lofly.git'],
  ['Woi Lafly', 'Woi Lofly'],
  ['LAFLY', 'LOFLY'],
  ['lafly', 'lofly'],
  ['Lafly', 'Lofly'],
].filter(([from, to]) => from !== to);

const files = execSync('git ls-files', { encoding: 'utf8' })
  .split('\n')
  .filter(Boolean)
  .filter((f) => !SKIP.has(f))
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