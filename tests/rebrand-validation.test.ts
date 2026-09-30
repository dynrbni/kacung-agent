import { describe, it, expect } from 'vitest';
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

const ROOT = process.cwd();
const PREVIOUS_BRAND = /kacung/i;

/**
 * Directories whose contents are generated, vendored, or binary. A stale match
 * here is not a stale reference in the product.
 */
const EXCLUDED_DIRS = ['.git', 'node_modules', 'dist', '.build', '.pnpm-store'];

const ALLOWED_HISTORICAL = [
  // The migration record itself documents the old identifiers on purpose.
  'scripts/migration/kacung-to-lafly.mjs',
];

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

  it('uses the Lafly package scope consistently', () => {
    const root = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'));
    expect(root.name).toBe('lafly-monorepo');
    expect(Object.keys(root.devDependencies).filter((d) => d.startsWith('@lafly/')).length).toBeGreaterThan(0);
    expect(root.devDependencies['@kacung/config']).toBeUndefined();

    const agent = JSON.parse(fs.readFileSync(path.join(ROOT, 'apps/agent/package.json'), 'utf8'));
    expect(agent.name).toBe('@lafly/agent');
  });

  it('ships the macOS app under the Lafly identity', () => {
    const plist = fs.readFileSync(path.join(ROOT, 'apps/macos/Info.plist'), 'utf8');
    expect(plist).toContain('<string>com.dynrbni.lafly</string>');
    expect(plist).toContain('<key>CFBundleDisplayName</key>\n    <string>Lafly</string>');
    expect(plist).not.toMatch(PREVIOUS_BRAND);

    const pkg = fs.readFileSync(path.join(ROOT, 'apps/macos/Package.swift'), 'utf8');
    expect(pkg).toContain('name: "Lafly"');
    expect(pkg).toContain('path: "Sources/LaflyApp"');
    expect(fs.existsSync(path.join(ROOT, 'apps/macos/Sources/LaflyApp'))).toBe(true);
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

    const rootPkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'));
    expect(rootPkg.scripts.test).toContain('SAFE_TEST_MODE=true');
    expect(rootPkg.scripts.test).toContain('LIVE_SIDE_EFFECTS=false');
  });
});
