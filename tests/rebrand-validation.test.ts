import { describe, it, expect } from 'vitest';
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

const ROOT = process.cwd();
const PREVIOUS_BRAND = /lafly/i;

/**
 * Directories whose contents are generated, vendored, or binary. A stale match
 * here is not a stale reference in the product.
 */
const EXCLUDED_DIRS = ['.git', 'node_modules', 'dist', '.build', '.pnpm-store'];

/**
 * Files that may still contain the previous brand, each with the reason it is
 * justified. Anything not listed here is an accidental reference.
 */
const ALLOWED_WITH_REASON: Record<string, string> = {
  // The migration records themselves document the old identifiers on purpose.
  'scripts/migration/kacung-to-lafly.mjs': 'one-off rename record kept for provenance',
  'scripts/migration/lafly-to-lofly.mjs': 'one-off rename record kept for provenance',
  // This file necessarily names the previous brand in order to detect it.
  'tests/rebrand-validation.test.ts': 'the stale-brand detector itself',
  // Documents the LOFLY_* -> LAFLY_* compatibility fallback for developers.
  'README.md': 'documents the legacy environment-variable fallback',
  // Reads the legacy names so an existing .env keeps its protection instead of
  // silently reverting to the permissive default.
  'packages/tools/src/safety/policy.ts': 'legacy LOFLY_* alias resolution',
};

const ALLOWED_HISTORICAL = Object.keys(ALLOWED_WITH_REASON);

function walk(dir: string, acc: string[] = []): string[] {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (EXCLUDED_DIRS.includes(entry.name) || entry.name.endsWith('.app')) continue;
      walk(full, acc);
    } else {
      acc.push(full);
    }
  }
  return acc;
}

function trackedSourceFiles(): string[] {
  const files = execSync('git ls-files', { encoding: 'utf8', cwd: ROOT })
    .split('\n')
    .filter(Boolean)
    .filter((f) => !f.endsWith('.app') && !EXCLUDED_DIRS.some((d) => f.startsWith(`${d}/`)));
  return files;
}

describe('Rebrand validation', () => {
  it('has no stale previous-brand references in tracked source', () => {
    const offenders: string[] = [];

    for (const file of trackedSourceFiles()) {
      if (ALLOWED_HISTORICAL.includes(file)) continue;

      const full = path.join(ROOT, file);
      let contents: string;
      try {
        contents = fs.readFileSync(full, 'utf8');
      } catch {
        continue;
      }
      if (PREVIOUS_BRAND.test(contents)) offenders.push(file);
    }

    expect(offenders, `stale brand references found in: ${offenders.join(', ')}`).toEqual([]);
  });

  it('has no previous-brand files or directories on disk', () => {
    const offenders = walk(ROOT)
      .map((f) => path.relative(ROOT, f))
      .filter((f) => !EXCLUDED_DIRS.some((d) => f.split(path.sep).includes(d)))
      .filter((f) => !f.endsWith('.app'))
      .filter((f) => !ALLOWED_HISTORICAL.includes(f))
      .filter((f) => PREVIOUS_BRAND.test(f));

    expect(offenders).toEqual([]);
  });

  it('uses the Lofly package scope consistently', () => {
    const root = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'));
    expect(root.name).toBe('lofly-monorepo');
    expect(Object.keys(root.devDependencies).filter((d) => d.startsWith('@lofly/')).length).toBeGreaterThan(0);
    expect(root.devDependencies['@lafly/config']).toBeUndefined();

    const agent = JSON.parse(fs.readFileSync(path.join(ROOT, 'apps/agent/package.json'), 'utf8'));
    expect(agent.name).toBe('@lofly/agent');
  });

  it('ships the macOS app under the Lofly identity', () => {
    const plist = fs.readFileSync(path.join(ROOT, 'apps/macos/Info.plist'), 'utf8');
    expect(plist).toContain('<string>com.dynrbni.lofly</string>');
    expect(plist).toContain('<key>CFBundleDisplayName</key>\n    <string>Lofly</string>');
    expect(plist).not.toMatch(PREVIOUS_BRAND);

    const pkg = fs.readFileSync(path.join(ROOT, 'apps/macos/Package.swift'), 'utf8');
    expect(pkg).toContain('name: "Lofly"');
    expect(pkg).toContain('path: "Sources/LoflyApp"');
    expect(fs.existsSync(path.join(ROOT, 'apps/macos/Sources/LoflyApp'))).toBe(true);
  });

  it('keeps the assistant persona and completion phrase intact', () => {
    // The rebrand changes identity only — tone and "Siap bos" must survive.
    const runtime = fs.readFileSync(path.join(ROOT, 'packages/core/src/agent/runtime.ts'), 'utf8');
    expect(runtime).toContain('Siap bos');
    expect(runtime).not.toMatch(PREVIOUS_BRAND);
  });

  it('keeps safe testing enabled by default', () => {
    const envExample = fs.readFileSync(path.join(ROOT, '.env.example'), 'utf8');
    expect(envExample).toContain('SAFE_TEST_MODE=true');
    expect(envExample).toContain('LIVE_SIDE_EFFECTS=false');
    expect(envExample).toContain('LOFLY_EXECUTION_MODE=dry_run');

    const rootPkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'));
    expect(rootPkg.scripts.test).toContain('SAFE_TEST_MODE=true');
    expect(rootPkg.scripts.test).toContain('LIVE_SIDE_EFFECTS=false');
  });

  it('defaults the assistant identity to Lofly', () => {
    const envExample = fs.readFileSync(path.join(ROOT, '.env.example'), 'utf8');
    expect(envExample).toContain('ASSISTANT_NAME=Lofly');
    expect(envExample).toContain('WAKE_PHRASE="Woi Lofly"');
  });

  it('still reads pre-rebrand LOFLY_* aliases without weakening the policy', () => {
    // A stale .env must keep its protection rather than silently reverting to
    // the permissive default, so the legacy names remain readable.
    const policy = fs.readFileSync(path.join(ROOT, 'packages/tools/src/safety/policy.ts'), 'utf8');
    expect(policy).toContain("env[`LAFLY_${key.slice('LOFLY_'.length)}`]");
    expect(policy).toContain('LOFLY_SANDBOX_ROOT');
    expect(policy).toContain('LOFLY_EXECUTION_MODE');
  });
});