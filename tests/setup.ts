/**
 * Global test guard.
 *
 * `pnpm test` must never be able to reach a real person, a real file, or a real
 * shell. This file pins the process into dry-run mode before any test module is
 * loaded, so a tool that forgets to check the policy still cannot execute.
 *
 * A test that genuinely needs live behaviour must construct its executor with
 * an explicit `policy` and declare LAFLY_TEST_ALLOW_LIVE=1, which makes the
 * opt-in greppable rather than implicit.
 */
import { beforeAll } from 'vitest';

const TEST_ENV = process.env.NODE_ENV === 'test' || process.env.VITEST === 'true';

if (TEST_ENV) {
  // Fail closed: override anything the shell or .env might have leaked in.
  process.env.SAFE_TEST_MODE = 'true';
  process.env.LIVE_SIDE_EFFECTS = 'false';
  process.env.LAFLY_ENV = 'test';

  beforeAll(() => {
    const violations: string[] = [];

    if (process.env.SAFE_TEST_MODE !== 'true') violations.push('SAFE_TEST_MODE must be "true" during tests');
    if (process.env.LIVE_SIDE_EFFECTS === 'true') violations.push('LIVE_SIDE_EFFECTS must not be "true" during tests');
    if (process.env.LAFLY_EXECUTION_MODE === 'live') violations.push('LAFLY_EXECUTION_MODE must not be "live" during tests');

    if (violations.length > 0) {
      throw new Error(
        `Safe testing violated:\n${violations.map((v) => `  - ${v}`).join('\n')}\n` +
          'Tests cannot perform live side effects. Use a mock executor or pin a sandbox policy instead.'
      );
    }
  });
}
